import tempfile
from typing import Any

from fastapi import HTTPException, status
from firebase_admin import firestore

from app.core.firebase import get_firestore_client
from app.schemas.patient import (
    AccountStatus,
    AccountStatusResponse,
    PatientProfile,
    PatientProfileUpdate,
)
from app.services.doctor_service import (MAX_AVATAR_BYTES,ALLOWED_IMAGE_CONTENT_TYPES,configure_cloudinary,)
from cloudinary.uploader import upload as cloudinary_upload

USERS_COLLECTION = "users"

# check if the user is active, archived, or suspended
def _read_status(data: dict[str, Any]) -> AccountStatus:
    raw = data.get("status")
    if isinstance(raw, str) and raw.lower() in {"active", "archived", "suspended"}:
        return raw.lower() 
    return "active"


def map_patient_profile(uid: str, data: dict[str, Any]) -> PatientProfile:
    return PatientProfile(
        uid=uid,
        full_name=str(data.get("fullName") or ""),
        email=data.get("email"),
        phone=data.get("phone"),
        avatar_url=data.get("avatar"),
        status=_read_status(data),
    )

# Gets a user's profile
def get_patient_profile(uid: str) -> PatientProfile:
    db = get_firestore_client()
    snapshot = db.collection(USERS_COLLECTION).document(uid).get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient profile not found.",
        )

    data = snapshot.to_dict() or {}
    _guard_archived(data)
    return map_patient_profile(uid, data)

# Updates name, phone, or photo
def update_patient_profile(uid: str, payload: PatientProfileUpdate) -> PatientProfile:
    db = get_firestore_client()
    doc_ref = db.collection(USERS_COLLECTION).document(uid)
    snapshot = doc_ref.get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient profile not found.",
        )

    data = snapshot.to_dict() or {}
    _guard_archived(data)

    update_fields: dict[str, object] = {}

    if payload.first_name is not None or payload.last_name is not None:
        current_full = str(data.get("fullName") or "").strip()
        parts = current_full.split(" ", 1)
        current_first = parts[0] if parts else ""
        current_last = parts[1] if len(parts) > 1 else ""

        new_first = payload.first_name.strip() if payload.first_name is not None else current_first
        new_last = payload.last_name.strip() if payload.last_name is not None else current_last
        update_fields["fullName"] = f"{new_first} {new_last}".strip()

    if payload.phone is not None:
        update_fields["phone"] = payload.phone

    if payload.avatar_url is not None:
        update_fields["avatar"] = payload.avatar_url

    if update_fields:
        update_fields["updatedAt"] = firestore.SERVER_TIMESTAMP
        doc_ref.update(update_fields)

    refreshed = doc_ref.get()
    return map_patient_profile(uid, refreshed.to_dict() or {})

# Sends the profile picture to the cloud and saves the link
def upload_patient_avatar(uid: str, content: bytes, content_type: str | None) -> str:
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
            detail="Unsupported file type. Use JPG, PNG, or WEBP.",
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
        with tempfile.NamedTemporaryFile(delete=False, suffix=extension) as tmp:
            tmp.write(content)
            temp_path = tmp.name

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
            detail=f"Failed to upload avatar: {exc}",
        ) from exc
    finally:
        if temp_path:
            import os
            try:
                os.unlink(temp_path)
            except OSError:
                pass

    secure_url = result.get("secure_url")
    if not isinstance(secure_url, str) or not secure_url:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Cloudinary did not return a URL.",
        )

    db = get_firestore_client()
    db.collection(USERS_COLLECTION).document(uid).set(
        {"avatar": secure_url, "updatedAt": firestore.SERVER_TIMESTAMP},
        merge=True,)

    return secure_url

# Gets the current status of the user's account
def get_account_status_for_uid(uid: str) -> AccountStatusResponse:
    db = get_firestore_client()
    snapshot = db.collection(USERS_COLLECTION).document(uid).get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )

    data = snapshot.to_dict() or {}
    return AccountStatusResponse(uid=uid, status=_read_status(data))

# Changes the account status
def set_account_status(uid: str, new_status: AccountStatus) -> AccountStatusResponse:
    db = get_firestore_client()
    doc_ref = db.collection(USERS_COLLECTION).document(uid)

    if not doc_ref.get().exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )

    doc_ref.update(
        {"status": new_status, "updatedAt": firestore.SERVER_TIMESTAMP}
    )
    return AccountStatusResponse(uid=uid, status=new_status)

# Blocks access if the account was deleted or archived
def _guard_archived(data: dict[str, Any]) -> None:
    # Raise 403 if the account has been archived
    acct_status = _read_status(data)
    if acct_status == "archived":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account has been deleted.",
        )
