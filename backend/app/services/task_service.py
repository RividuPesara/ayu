import logging
import re
from contextlib import contextmanager
from datetime import datetime, timezone
from typing import Any

from fastapi import HTTPException, status
from firebase_admin import firestore
from google.api_core import exceptions as api_exceptions
from google.cloud.firestore_v1.base_query import FieldFilter

from app.core.firebase import get_firestore_client
from app.schemas.task import TaskResponse

logger = logging.getLogger(__name__)

TASKS_COLLECTION = "tasks"

_VALID_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
_VALID_TIME_RE = re.compile(r"^\d{2}:\d{2}$")


@contextmanager
def _firestore_call():
    try:
        yield
    except (api_exceptions.ServiceUnavailable, api_exceptions.RetryError, api_exceptions.DeadlineExceeded) as exc:
        logger.warning("Firestore connectivity error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service temporarily unavailable. Please try again.",
        ) from exc


def _parse_firestore_timestamp(value: Any) -> datetime | None:
    # Convert Firestore timestamps and plain datetimes to UTCdatetime
    if isinstance(value, datetime):
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value
    if hasattr(value, "timestamp"):
        try:
            return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value
        except Exception:
            return None
    return None


def _map_task(doc_id: str, data: dict[str, Any]) -> TaskResponse:
    # Transform raw Firestore document into a Pydantic response
    return TaskResponse(
        task_id=doc_id,
        user_id=str(data.get("userId", "")),
        title=str(data.get("title", "")),
        date_key=str(data.get("dateKey", "")),
        time=str(data.get("time", "")),
        is_done=bool(data.get("isDone", False)),
        created_at=_parse_firestore_timestamp(data.get("createdAt")),
    )


def create_task(uid: str, title: str, date_key: str, time: str) -> TaskResponse:
    # Validate input abd write to Firestore and return the new task
    clean_title = title.strip()
    if not clean_title:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Task title is required.",
        )

    if not _VALID_DATE_RE.match(date_key):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="date_key must be in YYYY-MM-DD format.",
        )

    if not _VALID_TIME_RE.match(time):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="time must be in HH:MM format.",
        )

    with _firestore_call():
        db = get_firestore_client()
        ref = db.collection(TASKS_COLLECTION).document()
        ref.set(
            {
                "userId": uid,
                "title": clean_title,
                "dateKey": date_key,
                "time": time,
                "isDone": False,
                "createdAt": firestore.SERVER_TIMESTAMP,
            }
        )

        return TaskResponse(
            task_id=ref.id,
            user_id=uid,
            title=clean_title,
            date_key=date_key,
            time=time,
            is_done=False,
            created_at=datetime.now(tz=timezone.utc),
        )


def list_tasks(uid: str, date_key: str) -> list[TaskResponse]:
    # Return all tasks for this user on the given date ordered by creation time
    if not _VALID_DATE_RE.match(date_key):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="date_key must be in YYYY-MM-DD format.",
        )

    with _firestore_call():
        db = get_firestore_client()
        snapshots = (
            db.collection(TASKS_COLLECTION)
            .where(filter=FieldFilter("userId", "==", uid))
            .where(filter=FieldFilter("dateKey", "==", date_key))
            .order_by("createdAt", direction=firestore.Query.ASCENDING)
            .stream()
        )
        return [_map_task(snap.id, snap.to_dict() or {}) for snap in snapshots]


def toggle_task(uid: str, task_id: str) -> TaskResponse:
    # Flip isDone and return the updated task
    with _firestore_call():
        db = get_firestore_client()
        ref = db.collection(TASKS_COLLECTION).document(task_id)
        snap = ref.get()

        if not snap.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Task not found.",
            )

        data = snap.to_dict() or {}
        if str(data.get("userId", "")) != uid:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Task not found.",
            )

        new_state = not bool(data.get("isDone", False))
        ref.update({"isDone": new_state})

        return _map_task(task_id, {**data, "isDone": new_state})


def delete_task(uid: str, task_id: str) -> None:
    # Check ownership before removing the task document
    with _firestore_call():
        db = get_firestore_client()
        ref = db.collection(TASKS_COLLECTION).document(task_id)
        snap = ref.get()

        if not snap.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Task not found.",
            )

        data = snap.to_dict() or {}
        if str(data.get("userId", "")) != uid:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Task not found.",
            )

        ref.delete()
