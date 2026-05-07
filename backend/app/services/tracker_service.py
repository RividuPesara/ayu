import logging
import re
from contextlib import contextmanager
from datetime import datetime, timezone
from typing import Any
from zoneinfo import ZoneInfo

from fastapi import HTTPException, status
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from google.api_core import exceptions as api_exceptions

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.schemas.tracker import MedicationResponse, ScheduleItemResponse

logger = logging.getLogger(__name__)


@contextmanager
def _firestore_call():
    # Translate Firestore network failures into a 503 so callers receive a prompt error
    try:
        yield
    except (api_exceptions.ServiceUnavailable, api_exceptions.RetryError, api_exceptions.DeadlineExceeded) as exc:
        logger.warning("Firestore connectivity error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service temporarily unavailable. Please try again.",
        ) from exc

MEDICATIONS_COLLECTION = "medications"
MEDICATION_LOGS_COLLECTION = "medication_logs"

_VALID_TIME_RE = re.compile(r"^\d{2}:\d{2}$")
_VALID_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
_ALLOWED_TYPES = {"Capsule", "Injection"}


def _get_user_timezone() -> ZoneInfo:
    settings = get_settings()
    try:
        return ZoneInfo(settings.dashboard_timezone)
    except Exception:
        return ZoneInfo("UTC")


def _current_local_date_key() -> str:
    return datetime.now(tz=_get_user_timezone()).strftime("%Y-%m-%d")


def _current_local_time() -> str:
    return datetime.now(tz=_get_user_timezone()).strftime("%H:%M")


def _log_doc_id(uid: str, med_id: str, date_key: str, scheduled_time: str) -> str:
    # Composite key scoped to user, medication, date, and time slot
    return f"{uid}_{med_id}_{date_key}_{scheduled_time.replace(':', '')}"


def _parse_firestore_timestamp(value: Any) -> datetime | None:
    if isinstance(value, datetime):
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value
    if hasattr(value, "timestamp"):
        try:
            return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value
        except Exception:
            return None
    return None


def _map_medication(doc_id: str, data: dict[str, Any]) -> MedicationResponse:
    # Transform raw Firestore document into a Pydantic response
    return MedicationResponse(
        medication_id=doc_id,
        user_id=str(data.get("userId", "")),
        name=str(data.get("name", "")),
        type=str(data.get("type", "Capsule")),
        times=list(data.get("times", [])),
        repeat_until=str(data.get("repeatUntil", "")),
        start_date=str(data.get("startDate", "")),
        created_at=_parse_firestore_timestamp(data.get("createdAt")),
    )


def create_medication(uid: str,name: str,med_type: str,times: list[str],repeat_until: str,
) -> MedicationResponse:
    # Validate data and add the medication
    clean_name = name.strip()
    if not clean_name: 
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Medication name is required.",
        )

    if med_type not in _ALLOWED_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported medication type.",
        )

    if not _VALID_DATE_RE.match(repeat_until):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="repeat_until must be in YYYY-MM-DD format.",
        )

    clean_times = [t.strip() for t in times if _VALID_TIME_RE.match(t.strip())]
    if not clean_times:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one valid HH:MM time is required.",
        )

    date_key = _current_local_date_key()
    with _firestore_call():
        db = get_firestore_client()
        ref = db.collection(MEDICATIONS_COLLECTION).document()
        # Save the record to Firestore
        ref.set(
            {
                "userId": uid,
                "name": clean_name,
                "type": med_type,
                "times": clean_times,
                "repeatUntil": repeat_until,
                "startDate": date_key,
                "createdAt": firestore.SERVER_TIMESTAMP,
            }
        )

        return MedicationResponse(
            medication_id=ref.id,
            user_id=uid,
            name=clean_name,
            type=med_type,
            times=clean_times,
            repeat_until=repeat_until,
            start_date=date_key,
            created_at=datetime.now(tz=timezone.utc),
        )


def list_medications(uid: str) -> list[MedicationResponse]:
    # Return all medication definitions for this user ordered by creation time
    with _firestore_call():
        db = get_firestore_client()
        snapshots = (
            db.collection(MEDICATIONS_COLLECTION)
            .where(filter=FieldFilter("userId", "==", uid))
            .order_by("createdAt", direction=firestore.Query.ASCENDING)
            .stream()
        )
        return [_map_medication(snap.id, snap.to_dict() or {}) for snap in snapshots]


def delete_medication(uid: str, medication_id: str) -> None:
    # Validate ownership before removing the medication document
    with _firestore_call():
        db = get_firestore_client()
        ref = db.collection(MEDICATIONS_COLLECTION).document(medication_id)
        snap = ref.get()

        if not snap.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Medication not found.",
            )

        data = snap.to_dict() or {}
        if str(data.get("userId", "")) != uid:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Medication not found.",
            )

        ref.delete()


def mark_taken(uid: str, medication_id: str, date_key: str, scheduled_time: str) -> dict[str, Any]:
    # Record a dose as taken and validate the medication belongs to this user
    if not _VALID_DATE_RE.match(date_key):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="date_key must be in YYYY-MM-DD format.",
        )

    if not _VALID_TIME_RE.match(scheduled_time):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="scheduled_time must be in HH:MM format.",
        )

    with _firestore_call():
        db = get_firestore_client()
        med_snap = db.collection(MEDICATIONS_COLLECTION).document(medication_id).get()

        if not med_snap.exists or str((med_snap.to_dict() or {}).get("userId", "")) != uid:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Medication not found.",
            )

        med_data = med_snap.to_dict() or {}
        log_id = _log_doc_id(uid, medication_id, date_key, scheduled_time)

        db.collection(MEDICATION_LOGS_COLLECTION).document(log_id).set(
            {
                "userId": uid,
                "medicationId": medication_id,
                "medicationName": str(med_data.get("name", "")),
                "type": str(med_data.get("type", "")),
                "dateKey": date_key,
                "scheduledTime": scheduled_time,
                "status": "taken",
                "takenAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )

        return {"log_id": log_id, "status": "taken"}


def get_day_schedule(uid: str, date_key: str) -> dict[str, Any]:
    # Merge active medication definitions with daily logs to produce a full day view
    if not _VALID_DATE_RE.match(date_key):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="date_key must be in YYYY-MM-DD format.",
        )

    today_key = _current_local_date_key()
    current_time = _current_local_time()
    is_today = date_key == today_key
    is_past = date_key < today_key

    with _firestore_call():
        db = get_firestore_client()

        # Fetch medications still active on this date; filter startDate in Python
        # to avoid a Firestore multi-inequality compound index requirement
        med_snapshots = (
            db.collection(MEDICATIONS_COLLECTION)
            .where(filter=FieldFilter("userId", "==", uid))
            .where(filter=FieldFilter("repeatUntil", ">=", date_key))
            .stream()
        )

        meds: dict[str, dict[str, Any]] = {}
        for snap in med_snapshots:
            data = snap.to_dict() or {}
            if str(data.get("startDate", "")) <= date_key:
                meds[snap.id] = data

        # Fetch all logs created for this user on this date
        log_snapshots = (
            db.collection(MEDICATION_LOGS_COLLECTION)
            .where(filter=FieldFilter("userId", "==", uid))
            .where(filter=FieldFilter("dateKey", "==", date_key))
            .stream()
        )

        taken_slots: set[str] = set()
        log_id_map: dict[str, str] = {}

        for snap in log_snapshots:
            data = snap.to_dict() or {}
            if str(data.get("status", "")) == "taken":
                slot_key = f"{data.get('medicationId', '')}_{data.get('scheduledTime', '')}"
                taken_slots.add(slot_key)
                log_id_map[slot_key] = snap.id

        items: list[ScheduleItemResponse] = []

        for med_id, med_data in meds.items():
            for scheduled_time in list(med_data.get("times", [])):
                slot_key = f"{med_id}_{scheduled_time}"

                if slot_key in taken_slots:
                    slot_status = "taken"
                elif is_past:
                    slot_status = "missed"
                elif is_today and scheduled_time < current_time:
                    slot_status = "missed"
                else:
                    slot_status = "pending"

                items.append(
                    ScheduleItemResponse(
                        medication_id=med_id,
                        name=str(med_data.get("name", "")),
                        type=str(med_data.get("type", "Capsule")),
                        scheduled_time=scheduled_time,
                        status=slot_status,
                        log_id=log_id_map.get(slot_key),
                    )
                )

        items.sort(key=lambda x: x.scheduled_time)

        return {"date_key": date_key, "items": items}
