from typing import Any

from fastapi import HTTPException, status
from firebase_admin import firestore

from app.core.firebase import get_firestore_client
from app.schemas.doctor import (
    Appointment,
    AppointmentStatus,
    DoctorProfile,
    DoctorProfileUpdate,
    SessionSummaryUpdate,
)

APPOINTMENT_OWNER_FIELD = "uid"
DEFAULT_APPOINTMENTS_LIMIT = 500


# Extracts the doctor UID from an appointment document
def read_owner_uid(data: dict[str, Any]) -> str | None:
    value = data.get(APPOINTMENT_OWNER_FIELD)
    if isinstance(value, str) and value.strip():
        return value
    return None


# Maps Firestore doctor data into the DoctorProfile schema.
def map_profile(uid: str, data: dict[str, Any]) -> DoctorProfile:
    return DoctorProfile(
        uid=uid,
        full_name=str(data.get("fullName") or ""),
        specialty=data.get("specialty"),
        phone=data.get("phone"),
        avatar_url=data.get("avatar"),
        email=data.get("email"),
    )


# Normalizes appointment status into allowed values
def normalize_status(raw_status: Any) -> AppointmentStatus:
    value = str(raw_status or "upcoming").lower()
    if value in {"done", "upcoming", "overdue"}:
        return value  
    return "upcoming"


# Extracts date in year-month-day (YYYY-MM-DD) format
def to_date_key(raw_date: Any) -> str | None:
    if isinstance(raw_date, str):
        return raw_date.split("T")[0]

    return None


# Gets prescription URL from stored object
def read_prescription_url(raw_value: Any) -> str | None:
    if isinstance(raw_value, dict):
        value = raw_value.get("url")
        if isinstance(value, str):
            return value
    return None


# Gets prescription filename from stored object
def read_prescription_filename(raw_value: Any) -> str | None:
    if isinstance(raw_value, dict):
        value = raw_value.get("filename")
        if isinstance(value, str):
            return value
    return None


# Maps Firestore appointment data into the Appointment schema
def map_appointment(doc_id: str, data: dict[str, Any]) -> Appointment:
    return Appointment(
        id=doc_id,
        name=str(data.get("name") or ""),
        time=str(data.get("time") or ""),
        type=str(data.get("type") or "consultation"),
        status=normalize_status(data.get("status")),
        date=to_date_key(data.get("date")),
        zoom_meeting_id=data.get("zoomMeetingId"),
        zoom_passcode=data.get("zoomPasscode"),
        clinical_notes=data.get("clinicalNotes"),
        intake_note=data.get("intakeNote"),
        prescription_url=read_prescription_url(data.get("prescription")),
        prescription_filename=read_prescription_filename(data.get("prescription")),
    )


# Fetches appointment documents for a doctor using uid field only
def find_doctor_appointments(uid: str, limit: int) -> list[Appointment]:
    db = get_firestore_client()
    appointments_collection = db.collection("appointments")
    snapshots = appointments_collection.where(APPOINTMENT_OWNER_FIELD, "==", uid).limit(limit).stream()
    return [map_appointment(snapshot.id, snapshot.to_dict() or {}) for snapshot in snapshots]


# Loads a single appointment and make sure that the current doctor owns it
def get_owned_appointment(uid: str, appointment_id: str):
    db = get_firestore_client()
    doc_ref = db.collection("appointments").document(appointment_id)
    snapshot = doc_ref.get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Appointment not found.",
        )

    data = snapshot.to_dict() or {}
    if read_owner_uid(data) != uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You cannot access this appointment.",
        )

    return doc_ref, data


# Returns doctor profile details for the given doctor user id
def get_doctor_profile(uid: str) -> DoctorProfile:
    db = get_firestore_client()
    snapshot = db.collection("doctors").document(uid).get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Doctor profile not found.",
        )

    return map_profile(uid, snapshot.to_dict() or {})


# Updates doctor profile fields
def update_doctor_profile(uid: str, payload: DoctorProfileUpdate) -> DoctorProfile:
    db = get_firestore_client()
    doc_ref = db.collection("doctors").document(uid)

    update_data: dict[str, object] = {}
    if payload.full_name is not None:
        update_data["fullName"] = payload.full_name
    if payload.specialty is not None:
        update_data["specialty"] = payload.specialty
    if payload.phone is not None:
        update_data["phone"] = payload.phone
    if payload.avatar_url is not None:
        update_data["avatar"] = payload.avatar_url

    if update_data:
        update_data["updatedAt"] = firestore.SERVER_TIMESTAMP
        doc_ref.set(update_data, merge=True)

    return get_doctor_profile(uid)


# Returns doctor appointments for the current doctor
def list_doctor_appointments(uid: str) -> list[Appointment]:
    appointments = find_doctor_appointments(uid, DEFAULT_APPOINTMENTS_LIMIT)
    appointments.sort(key=lambda item: item.time)
    return appointments


# Gets a single appointment for the doctor
def get_doctor_appointment(uid: str, appointment_id: str) -> Appointment:
    _, data = get_owned_appointment(uid, appointment_id)
    return map_appointment(appointment_id, data)


# Updates appointment status and return the updated appointment
def update_appointment_status(
    uid: str,
    appointment_id: str,
    new_status: AppointmentStatus,
) -> Appointment:
    doc_ref, _ = get_owned_appointment(uid, appointment_id)

    doc_ref.update(
        {"status": new_status,
        "updatedAt": firestore.SERVER_TIMESTAMP,
        }
    )

    return get_doctor_appointment(uid, appointment_id)

# Saves consultation notes and prescription info
def save_session_summary(
    uid: str,
    appointment_id: str,
    payload: SessionSummaryUpdate,
) -> Appointment:
    doc_ref, current_data = get_owned_appointment(uid, appointment_id)

    update_data: dict[str, object] = {"updatedAt": firestore.SERVER_TIMESTAMP}

    if payload.clinical_notes is not None:
        update_data["clinicalNotes"] = payload.clinical_notes

    if payload.prescription_url is not None or payload.prescription_filename is not None:
        existing_prescription = current_data.get("prescription")
        if not isinstance(existing_prescription, dict):
            existing_prescription = {}

        if payload.prescription_url is not None:
            existing_prescription["url"] = payload.prescription_url
        if payload.prescription_filename is not None:
            existing_prescription["filename"] = payload.prescription_filename

        update_data["prescription"] = existing_prescription

    doc_ref.update(update_data)
    return get_doctor_appointment(uid, appointment_id)
