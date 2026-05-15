import os
import re
import tempfile
from datetime import date as date_type
from datetime import datetime, timedelta, timezone, tzinfo
from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import cloudinary
from cloudinary.uploader import upload as cloudinary_upload
from fastapi import HTTPException, status
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.schemas.doctor import (
    Appointment,
    AppointmentFileCategory,
    AppointmentStatus,
    DoctorProfile,
    DoctorProfileUpdate,
    SessionSummaryUpdate,
)

APPOINTMENT_OWNER_FIELD = "doctorUid"
DEFAULT_APPOINTMENTS_LIMIT = 500
MAX_AVATAR_BYTES = 5 * 1024 * 1024
MAX_APPOINTMENT_FILE_BYTES = 10 * 1024 * 1024
ALLOWED_IMAGE_CONTENT_TYPES = {"image/jpeg", "image/jpg", "image/png", "image/webp"}
ALLOWED_APPOINTMENT_FILE_CONTENT_TYPES = {
    "application/pdf",
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
}
_cloudinary_configured = False
USERS_COLLECTION = "users"
APPOINTMENT_TIMEZONE_FALLBACK = "Asia/Colombo"


 # Extracts the doctor UID from an appointment document
def read_owner_uid(data: dict[str, Any]) -> str | None:
    value = data.get(APPOINTMENT_OWNER_FIELD)
    if isinstance(value, str) and value.strip():
        return value
    return None


# Extracts the patient UID from an appointment document
def read_patient_uid(data: dict[str, Any]) -> str | None:
    value = data.get("patientUid")
    if isinstance(value, str) and value.strip():
        return value
    return None


# Return the dashboard timezone from settings or fall back to a default or UTC if invalid
def resolve_dashboard_timezone() -> tzinfo:
    settings = get_settings()
    timezone_name = (settings.dashboard_timezone or APPOINTMENT_TIMEZONE_FALLBACK).strip()
    try:
        return ZoneInfo(timezone_name)
    except ZoneInfoNotFoundError:
        if timezone_name == "Asia/Colombo":
            return timezone(timedelta(hours=5, minutes=30))
        return timezone.utc


# Converts a HH:MM time string to minutes since midnight
def parse_time_to_minutes(raw_time: Any) -> int | None:
    if not isinstance(raw_time, str):
        return None

    normalized = raw_time.strip()
    if not normalized:
        return None

    match = re.match(r"^([01]\d|2[0-3]):([0-5]\d)$", normalized)
    if not match:
        return None

    hour = int(match.group(1))
    minute = int(match.group(2))
    return hour * 60 + minute

def parse_date_value(raw_date: Any) -> date_type | None:
    if isinstance(raw_date, datetime):
        return raw_date.date()

    if isinstance(raw_date, date_type):
        return raw_date

    if isinstance(raw_date, str):
        normalized = raw_date.strip()
        if not normalized:
            return None

        try:
            return datetime.strptime(normalized, "%Y-%m-%d").date()
        except ValueError:
            return None

    return None

# Create a datetime for an appointment using date, time, and timezone
def build_appointment_datetime(
    date_key: str | None,
    raw_time: str,
    timezone_info: tzinfo,
) -> datetime | None:
    parsed_date = parse_date_value(date_key)
    parsed_minutes = parse_time_to_minutes(raw_time)

    if parsed_date is None or parsed_minutes is None:
        return None

    hour = parsed_minutes // 60
    minute = parsed_minutes % 60
    return datetime(
        parsed_date.year,
        parsed_date.month,
        parsed_date.day,
        hour,
        minute,
        tzinfo=timezone_info,
    )

# Configure Cloudinary only once
def configure_cloudinary() -> None:
    global _cloudinary_configured
    if _cloudinary_configured:
        return

    settings = get_settings()
    if (
        settings.cloudinary_cloud_name
        and settings.cloudinary_api_key
        and settings.cloudinary_api_secret
    ):
        cloudinary.config(
            cloud_name=settings.cloudinary_cloud_name,
            api_key=settings.cloudinary_api_key,
            api_secret=settings.cloudinary_api_secret,
            secure=True,
        )
        _cloudinary_configured = True
        return

    if settings.cloudinary_url:
        cloudinary.config(cloudinary_url=settings.cloudinary_url.strip(), secure=True)
        _cloudinary_configured = True
        return

    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Cloudinary configuration is missing.",
    )

# Upload a doctor avatar image to cloudinary this will return the secure URL
def upload_avatar_to_cloudinary(uid: str, content: bytes, content_type: str | None) -> str:
    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Avatar file is empty.",
        )

    if len(content) > MAX_AVATAR_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Avatar file is too large. Max size is 5MB.",
        )

    if content_type and content_type.lower() not in ALLOWED_IMAGE_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported avatar file type. Use JPG, PNG, or WEBP.",
        )

    configure_cloudinary()

    extension = ".jpg"
    if content_type:
        lowered = content_type.lower()
        if lowered == "image/png":
            extension = ".png"
        elif lowered == "image/webp":
            extension = ".webp"

    temp_path: str | None = None

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=extension) as temp_file:
            temp_file.write(content)
            temp_path = temp_file.name

        result = cloudinary_upload(
            temp_path,
            folder=f"ayu/users/{uid}",
            public_id="avatar",
            resource_type="image",
            overwrite=True,
            invalidate=True,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to upload avatar to Cloudinary: {exc}",
        ) from exc
    finally:
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except OSError:
                pass

    secure_url = result.get("secure_url")
    if not isinstance(secure_url, str) or not secure_url:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Cloudinary did not return a secure image URL.",
        )

    return secure_url


# Reads the doctor's specialty
def read_doctor_specialty(data: dict[str, Any]) -> str | None:
    doctor_profile = data.get("doctorProfile")
    if isinstance(doctor_profile, dict):
        specialty = doctor_profile.get("specialty")
        if isinstance(specialty, str) and specialty.strip():
            return specialty

    return None


# Reads the doctor's phone number
def read_profile_phone(data: dict[str, Any]) -> str | None:
    phone = data.get("phone")
    if isinstance(phone, str) and phone.strip():
        return phone
    return None


# Maps Firestore doctor data into the DoctorProfile schema.
def map_profile(uid: str, data: dict[str, Any]) -> DoctorProfile:
    return DoctorProfile(
        uid=uid,
        full_name=str(data.get("fullName") or ""),
        specialty=read_doctor_specialty(data),
        phone=read_profile_phone(data),
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
    parsed_date = parse_date_value(raw_date)
    if parsed_date is None:
        return None
    return parsed_date.isoformat()


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

# extract the documentation url from Firestore
def read_documentation_url(raw_value: Any) -> str | None:
    if isinstance(raw_value, dict):
        value = raw_value.get("url")
        if isinstance(value, str):
            return value
    return None

# extracts documentation filename from Firestore 
def read_documentation_filename(raw_value: Any) -> str | None:
    if isinstance(raw_value, dict):
        value = raw_value.get("filename")
        if isinstance(value, str):
            return value
    return None


# Maps Firestore appointment data into the Appointment schema
def map_appointment(doc_id: str, data: dict[str, Any]) -> Appointment:
    return Appointment(
        id=doc_id,
        doctor_uid=read_owner_uid(data),
        patient_uid=read_patient_uid(data),
        name=str(data.get("name") or ""),
        time=str(data.get("time") or ""),
        type=str(data.get("type") or "consultation"),
        status=normalize_status(data.get("status")),
        date=to_date_key(data.get("date")),
        zoom_meeting_id=data.get("zoomMeetingId"),
        zoom_passcode=data.get("zoomPasscode"),
        zoom_start_url=data.get("zoomStartUrl"),
        clinical_notes=data.get("clinicalNotes"),
        intake_note=data.get("intakeNote"),
        prescription_url=read_prescription_url(data.get("prescription")),
        prescription_filename=read_prescription_filename(data.get("prescription")),
        documentation_url=read_documentation_url(data.get("documentation")),
        documentation_filename=read_documentation_filename(data.get("documentation")),
    )


# Determines the runtime status overdue/upcoming/done for an appointment
def resolve_runtime_status(
    current_status: AppointmentStatus,
    appointment_date: str | None,
    appointment_time: str,
    now: datetime,
    timezone_info: tzinfo,
) -> AppointmentStatus:
    if current_status == "done":
        return "done"

    appointment_datetime = build_appointment_datetime(
        appointment_date,
        appointment_time,
        timezone_info,
    )
    if appointment_datetime is None:
        return current_status

    return "overdue" if appointment_datetime < now else "upcoming"


# Applies runtime status to an appointment object
def apply_runtime_status(
    appointment: Appointment,
    now: datetime,
    timezone_info: tzinfo,
) -> Appointment:
    appointment.status = resolve_runtime_status(
        appointment.status,
        appointment.date,
        appointment.time,
        now,
        timezone_info,
    )
    return appointment


# Sort appointments by time
def appointment_sort_key(appointment: Appointment) -> tuple[int, int, str]:
    minutes = parse_time_to_minutes(appointment.time)
    if minutes is not None:
        return (0, minutes, "")
    return (1, 0, appointment.time)


# Fetches appointment documents for a doctor using doctorUid field.
def find_doctor_appointments(uid: str, limit: int) -> list[Appointment]:
    db = get_firestore_client()
    appointments_collection = db.collection("appointments")
    snapshots = appointments_collection.where(filter=FieldFilter(APPOINTMENT_OWNER_FIELD, "==", uid)).limit(limit).stream()
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
    snapshot = db.collection(USERS_COLLECTION).document(uid).get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Doctor profile not found.",
        )

    return map_profile(uid, snapshot.to_dict() or {})


# Updates doctor profile fields
def update_doctor_profile(uid: str, payload: DoctorProfileUpdate) -> DoctorProfile:
    db = get_firestore_client()
    doc_ref = db.collection(USERS_COLLECTION).document(uid)
    snapshot = doc_ref.get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Doctor profile not found.",
        )

    update_data: dict[str, object] = {}
    if payload.full_name is not None:
        update_data["fullName"] = payload.full_name
    if payload.specialty is not None:
        update_data["doctorProfile.specialty"] = payload.specialty
    if payload.phone is not None:
        update_data["phone"] = payload.phone
    if payload.avatar_url is not None:
        update_data["avatar"] = payload.avatar_url

    if update_data:
        update_data["updatedAt"] = firestore.SERVER_TIMESTAMP
        doc_ref.update(update_data)

    refreshed = doc_ref.get()
    return map_profile(uid, refreshed.to_dict() or {})

# Uploads and updates doctor avatar in Cloudinary and Firestore
def update_doctor_avatar(uid: str, avatar_file_bytes: bytes, content_type: str | None) -> str:
    avatar_url = upload_avatar_to_cloudinary(uid, avatar_file_bytes, content_type)
    db = get_firestore_client()
    doc_ref = db.collection(USERS_COLLECTION).document(uid)
    doc_ref.set(
        {
            "avatar": avatar_url,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )
    return avatar_url

# Uploads a file for appointment category in Cloudinary
def upload_appointment_file_to_cloudinary(
    uid: str,
    appointment_id: str,
    category: AppointmentFileCategory,
    content: bytes,
    content_type: str | None,
    filename: str | None,
) -> tuple[str, str]:
    if not content:  # Reject empty uploads
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty.",
        )

    if len(content) > MAX_APPOINTMENT_FILE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="File is too large. Max size is 10MB.",
        )

    if content_type and content_type.lower() not in ALLOWED_APPOINTMENT_FILE_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported file type. Use PDF, JPG, PNG, or WEBP.",
        )
    
    # Make sure the doctor owns this appointment before uploading
    _, _ = get_owned_appointment(uid, appointment_id)
    configure_cloudinary()

    extension = ".bin"
    if content_type:
        lowered = content_type.lower()
        if lowered in {"image/jpeg", "image/jpg"}:
            extension = ".jpg"
        elif lowered == "image/png":
            extension = ".png"
        elif lowered == "image/webp":
            extension = ".webp"
        elif lowered == "application/pdf":
            extension = ".pdf"

    temp_path: str | None = None

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=extension) as temp_file:
            temp_file.write(content)
            temp_path = temp_file.name
        # Upload file to cloudinary in appointment folder
        result = cloudinary_upload(
            temp_path,
            folder=f"ayu/appointments/{appointment_id}/{category}",
            resource_type="auto",
            overwrite=True,
            invalidate=True,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to upload {category} to Cloudinary: {exc}",
        ) from exc
    finally:
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except OSError:
                pass
    # Extract the final url from cloudinary response
    secure_url = result.get("secure_url")
    if not isinstance(secure_url, str) or not secure_url:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Cloudinary did not return a secure file URL.",
        )

    clean_filename = (filename or "uploaded-file").strip() or "uploaded-file"
    return secure_url, clean_filename  


# Returns doctor appointments for the current doctor
def list_doctor_appointments(uid: str) -> list[Appointment]:
    timezone_info = resolve_dashboard_timezone()
    now = datetime.now(timezone_info)

    appointments = [
        apply_runtime_status(item, now, timezone_info)
        for item in find_doctor_appointments(uid, DEFAULT_APPOINTMENTS_LIMIT)
    ]
    appointments.sort(key=appointment_sort_key)
    return appointments


# Gets a single appointment for the doctor
def get_doctor_appointment(uid: str, appointment_id: str) -> Appointment:
    _, data = get_owned_appointment(uid, appointment_id)
    timezone_info = resolve_dashboard_timezone()
    now = datetime.now(timezone_info)
    appointment = map_appointment(appointment_id, data)
    return apply_runtime_status(appointment, now, timezone_info)


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

    refreshed = doc_ref.get()
    timezone_info = resolve_dashboard_timezone()
    now = datetime.now(timezone_info)
    appointment = map_appointment(appointment_id, refreshed.to_dict() or {})
    return apply_runtime_status(appointment, now, timezone_info)

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

    if payload.documentation_url is not None or payload.documentation_filename is not None:
        existing_documentation = current_data.get("documentation")
        if not isinstance(existing_documentation, dict):
            existing_documentation = {}

        if payload.documentation_url is not None:
            existing_documentation["url"] = payload.documentation_url
        if payload.documentation_filename is not None:
            existing_documentation["filename"] = payload.documentation_filename

        update_data["documentation"] = existing_documentation

    doc_ref.update(update_data)

    refreshed = doc_ref.get()
    timezone_info = resolve_dashboard_timezone()
    now = datetime.now(timezone_info)
    appointment = map_appointment(appointment_id, refreshed.to_dict() or {})
    return apply_runtime_status(appointment, now, timezone_info)
