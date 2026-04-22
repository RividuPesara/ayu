from datetime import datetime, timedelta, tzinfo
from typing import Any

from fastapi import HTTPException, status
from firebase_admin import firestore

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.schemas.appointments import (
    AppointmentSlotDate,
    AppointmentSlotTime,
    AppointmentSlotsResponse,
    AppointmentSlotsRequest,
    BookAppointmentRequest,
    BookAppointmentResponse,
    PatientAppointment,
)
from app.schemas.doctor import AppointmentStatus
from app.services.doctor_service import (
    build_appointment_datetime,
    parse_time_to_minutes,
    resolve_dashboard_timezone,
)
from app.services.zoom_service import create_zoom_meeting, get_zoom_user_id_by_email

APPOINTMENTS_COLLECTION = "appointments"
DEFAULT_APPOINTMENT_TIMES = [
    "09:00",
    "09:30",
    "10:00",
    "10:30",
    "11:00",
    "15:00",
    "15:30",
]
DEFAULT_SLOT_DAYS = 5


def _normalize_time_value(raw_time: str) -> str | None:
    if parse_time_to_minutes(raw_time) is None:
        return None

    parts = raw_time.split(":")
    if len(parts) != 2:
        return None

    return f"{parts[0].zfill(2)}:{parts[1].zfill(2)}"


def _build_slot_dates(now: datetime, days: int) -> list[AppointmentSlotDate]:
    dates: list[AppointmentSlotDate] = []
    current_date = now.date()

    for offset in range(days):
        date_value = current_date + timedelta(days=offset)
        date_key = date_value.isoformat()
        day = str(date_value.day)
        weekday = date_value.strftime("%a")
        dates.append(
            AppointmentSlotDate(
                date_key=date_key,
                day=day,
                weekday=weekday,
                times=[AppointmentSlotTime(time=time) for time in DEFAULT_APPOINTMENT_TIMES],
            )
        )

    return dates


def list_available_slots(payload: AppointmentSlotsRequest) -> AppointmentSlotsResponse:
    settings = get_settings()
    timezone_info = resolve_dashboard_timezone()
    now = datetime.now(timezone_info)

    dates = _build_slot_dates(now, DEFAULT_SLOT_DAYS)
    date_keys = [item.date_key for item in dates]

    taken_slots: set[tuple[str, str]] = set()
    if date_keys:
        db = get_firestore_client()
        snapshots = (
            db.collection(APPOINTMENTS_COLLECTION)
            .where("doctorUid", "==", payload.doctor_uid)
            .where("date", "in", date_keys)
            .stream()
        )
        for snapshot in snapshots:
            data = snapshot.to_dict() or {}
            date_key = data.get("date")
            time_value = data.get("time")
            if isinstance(date_key, str) and isinstance(time_value, str):
                taken_slots.add((date_key, time_value))

    # Block same-day times that already passed for patients.
    current_date_key = now.date().isoformat()
    current_minutes = now.hour * 60 + now.minute

    for date_item in dates:
        for time_item in date_item.times:
            is_taken = (date_item.date_key, time_item.time) in taken_slots
            is_past_today = False
            if date_item.date_key == current_date_key:
                slot_minutes = parse_time_to_minutes(time_item.time)
                if slot_minutes is not None and slot_minutes < current_minutes:
                    is_past_today = True
            time_item.available = not is_taken and not is_past_today

    return AppointmentSlotsResponse(timezone=str(settings.dashboard_timezone), dates=dates)


def _map_patient_appointment(doc_id: str, data: dict[str, Any]) -> PatientAppointment:
    raw_status = str(data.get("status") or "upcoming").lower()
    status: AppointmentStatus = raw_status if raw_status in {"done", "upcoming", "overdue"} else "upcoming"
    return PatientAppointment(
        id=doc_id,
        doctor_name=str(data.get("doctorName") or ""),
        doctor_specialty=data.get("doctorSpecialty"),
        doctor_avatar_url=data.get("doctorAvatar"),
        date_key=str(data.get("date") or "") or None,
        time=str(data.get("time") or ""),
        type=str(data.get("type") or "consultation"),
        status=status,
        zoom_meeting_id=data.get("zoomMeetingId"),
        zoom_passcode=data.get("zoomPasscode"),
        zoom_join_url=data.get("zoomJoinUrl"),
        prescription_url=(data.get("prescription") or {}).get("url") if isinstance(data.get("prescription"), dict) else None,
        prescription_filename=(data.get("prescription") or {}).get("filename") if isinstance(data.get("prescription"), dict) else None,
        documentation_url=(data.get("documentation") or {}).get("url") if isinstance(data.get("documentation"), dict) else None,
        documentation_filename=(data.get("documentation") or {}).get("filename") if isinstance(data.get("documentation"), dict) else None,
    )


def _apply_patient_runtime_status(
    appointment: PatientAppointment,
    now: datetime,
    timezone_info: tzinfo,
) -> PatientAppointment:
    # Keep done status stable; otherwise compute overdue/upcoming on read.
    if appointment.status == "done":
        return appointment

    appointment_datetime = build_appointment_datetime(
        appointment.date_key,
        appointment.time,
        timezone_info,
    )
    if appointment_datetime is None:
        return appointment

    appointment.status = "overdue" if appointment_datetime < now else "upcoming"
    return appointment


def list_patient_appointments(uid: str) -> list[PatientAppointment]:
    db = get_firestore_client()
    snapshots = (
        db.collection(APPOINTMENTS_COLLECTION)
        .where("patientUid", "==", uid)
        .stream()
    )
    # Apply runtime status for patient appointments using dashboard timezone.
    timezone_info = resolve_dashboard_timezone()
    now = datetime.now(timezone_info)
    appointments = [
        _apply_patient_runtime_status(
            _map_patient_appointment(snapshot.id, snapshot.to_dict() or {}),
            now,
            timezone_info,
        )
        for snapshot in snapshots
    ]
    appointments.sort(key=lambda item: ((item.date_key or ""), item.time))
    return appointments


def _build_slot_doc_id(doctor_uid: str, date_key: str, time_value: str) -> str:
    return f"slot_{doctor_uid}_{date_key}_{time_value.replace(':', '')}"


def _read_doctor_email(data: dict[str, Any]) -> str | None:
    email = data.get("email")
    if isinstance(email, str) and email.strip():
        return email.strip()
    return None


def resolve_zoom_user_id_for_doctor(doctor_uid: str) -> str:
    settings = get_settings()
    db = get_firestore_client()
    doc_ref = db.collection("users").document(doctor_uid)
    snapshot = doc_ref.get()

    if snapshot.exists:
        data = snapshot.to_dict() or {}
        cached_zoom_user_id = data.get("zoomUserId")
        if isinstance(cached_zoom_user_id, str) and cached_zoom_user_id.strip():
            return cached_zoom_user_id.strip()

        email = _read_doctor_email(data)
        if email:
            zoom_user_id = get_zoom_user_id_by_email(email)
            if zoom_user_id:
                doc_ref.set(
                    {
                        "zoomUserId": zoom_user_id,
                        "updatedAt": firestore.SERVER_TIMESTAMP,
                    },
                    merge=True,
                )
                return zoom_user_id

    fallback = (settings.zoom_user_id or "me").strip() or "me"
    return fallback


def read_doctor_avatar(doctor_uid: str) -> str | None:
    db = get_firestore_client()
    snapshot = db.collection("users").document(doctor_uid).get()
    if not snapshot.exists:
        return None

    data = snapshot.to_dict() or {}
    avatar = data.get("avatar")
    if isinstance(avatar, str) and avatar.strip():
        return avatar.strip()
    return None


def book_appointment(
    *,
    uid: str,
    user_email: str | None,
    user_name: str | None,
    payload: BookAppointmentRequest,
) -> BookAppointmentResponse:
    normalized_time = _normalize_time_value(payload.time)
    if normalized_time is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid time format. Use HH:MM.",
        )

    if normalized_time not in DEFAULT_APPOINTMENT_TIMES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Selected time is not available.",
        )

    timezone_info = resolve_dashboard_timezone()
    appointment_dt = build_appointment_datetime(payload.date_key, normalized_time, timezone_info)
    if appointment_dt is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid appointment date.",
        )

    db = get_firestore_client()
    doc_id = _build_slot_doc_id(payload.doctor_uid, payload.date_key, normalized_time)
    doc_ref = db.collection(APPOINTMENTS_COLLECTION).document(doc_id)
    if doc_ref.get().exists:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This time slot is already booked.",
        )

    settings = get_settings()
    zoom_user_id = resolve_zoom_user_id_for_doctor(payload.doctor_uid)
    meeting = create_zoom_meeting(
        user_id=zoom_user_id,
        topic=f"AYU Appointment - {payload.doctor_name}",
        start_time=appointment_dt,
        duration_minutes=settings.appointment_duration_minutes,
        timezone_name=str(settings.dashboard_timezone),
    )

    meeting_id = str(meeting.get("id")) if meeting.get("id") is not None else None
    passcode = meeting.get("password")
    join_url = meeting.get("join_url")

    appointment_payload: dict[str, Any] = {
        "doctorUid": payload.doctor_uid,
        "doctorName": payload.doctor_name,
        "doctorSpecialty": payload.doctor_specialty,
        "doctorAvatar": read_doctor_avatar(payload.doctor_uid),
        "patientUid": uid,
        "patientEmail": user_email,
        "patientName": user_name,
        "name": user_name or "Patient",
        "type": payload.type,
        "status": "upcoming",
        "date": payload.date_key,
        "time": normalized_time,
        "intakeNote": payload.intake_note,
        "zoomMeetingId": meeting_id,
        "zoomPasscode": passcode,
        "zoomJoinUrl": join_url,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }

    transaction = db.transaction()

    @firestore.transactional
    def _create_appointment(tx: firestore.Transaction) -> None:
        snapshot = doc_ref.get(transaction=tx)
        if snapshot.exists:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This time slot is already booked.",
            )
        tx.set(doc_ref, appointment_payload)

    try:
        _create_appointment(transaction)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create the appointment.",
        ) from exc

    return BookAppointmentResponse(
        appointment_id=doc_id,
        date_key=payload.date_key,
        time=normalized_time,
        zoom_meeting_id=meeting_id,
        zoom_passcode=passcode,
        zoom_join_url=join_url,
    )
