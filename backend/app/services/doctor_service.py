import os
import tempfile
from typing import Any

import cloudinary
from cloudinary.uploader import upload as cloudinary_upload
from fastapi import HTTPException, status
from firebase_admin import firestore

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

APPOINTMENT_OWNER_FIELD = "uid"
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


# Extracts the doctor UID from an appointment document
def read_owner_uid(data: dict[str, Any]) -> str | None:
    value = data.get(APPOINTMENT_OWNER_FIELD)
    if isinstance(value, str) and value.strip():
        return value
    return None

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
            folder=f"ayu/doctors/{uid}",
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
        documentation_url=read_documentation_url(data.get("documentation")),
        documentation_filename=read_documentation_filename(data.get("documentation")),
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

# Uploads and updates doctor avatar in Cloudinary and Firestore
def update_doctor_avatar(uid: str, avatar_file_bytes: bytes, content_type: str | None) -> str:
    avatar_url = upload_avatar_to_cloudinary(uid, avatar_file_bytes, content_type)
    db = get_firestore_client()
    doc_ref = db.collection("doctors").document(uid)
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
    return get_doctor_appointment(uid, appointment_id)
