from typing import Any

from fastapi import HTTPException, status

from google.cloud.firestore_v1.base_query import FieldFilter

from app.core.firebase import get_firestore_client
from app.schemas.doctors import DoctorSummary

USERS_COLLECTION = "users"
DEFAULT_DOCTOR_LIMIT = 200

# extracts the medical specialty from the nested doctor profile
def _read_doctor_specialty(data: dict[str, Any]) -> str | None:
    doctor_profile = data.get("doctorProfile")
    if isinstance(doctor_profile, dict):
        specialty = doctor_profile.get("specialty")
        if isinstance(specialty, str) and specialty.strip():
            return specialty.strip()
    return None


def _read_phone(data: dict[str, Any]) -> str | None:
    phone = data.get("phone")
    if isinstance(phone, str) and phone.strip():
        return phone.strip()
    return None

# returns the phone number if it exists
def _read_avatar(data: dict[str, Any]) -> str | None:
    avatar = data.get("avatar")
    if isinstance(avatar, str) and avatar.strip():
        return avatar.strip()
    return None

# Checks for a valid profile picture URL
def _map_doctor(uid: str, data: dict[str, Any]) -> DoctorSummary:
    return DoctorSummary(
        uid=uid,
        full_name=str(data.get("fullName") or ""),
        specialty=_read_doctor_specialty(data),
        phone=_read_phone(data),
        avatar_url=_read_avatar(data),
        email=data.get("email"),
    )

# Converts raw Firestore dictionary data into a clean DoctorSummary object
def list_doctors(limit: int = DEFAULT_DOCTOR_LIMIT) -> list[DoctorSummary]:
    db = get_firestore_client()
    snapshots = (
        db.collection(USERS_COLLECTION)
        .where(filter=FieldFilter("role", "==", "doctor"))
        .limit(limit)
        .stream()
    )

    return [_map_doctor(snapshot.id, snapshot.to_dict() or {}) for snapshot in snapshots]

# Finds one specific doctor and double checks they have the correct role
def get_doctor_by_uid(uid: str) -> DoctorSummary:
    db = get_firestore_client()
    snapshot = db.collection(USERS_COLLECTION).document(uid).get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Doctor not found.",
        )

    data = snapshot.to_dict() or {}
    role = data.get("role")
    if isinstance(role, str) and role.lower() != "doctor":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Doctor not found.",
        )

    return _map_doctor(uid, data)
