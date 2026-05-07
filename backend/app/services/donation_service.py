import tempfile
import os
from datetime import datetime, timezone

import cloudinary
import cloudinary.uploader
from fastapi import HTTPException, UploadFile, status
from firebase_admin import firestore

from app.core.config import get_settings
from app.core.firebase import get_firestore_client

DONATION_COLLECTION = "donationApplications"

ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/jpg", "image/png", "application/pdf"}
ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png", "pdf"}
MAX_FILE_BYTES = 10 * 1024 * 1024  # 10 MB max

_cloudinary_configured = False


def _configure_cloudinary() -> None:
    global _cloudinary_configured
    if _cloudinary_configured:
        return
    settings = get_settings()
    if settings.cloudinary_cloud_name and settings.cloudinary_api_key and settings.cloudinary_api_secret:
        cloudinary.config(
            cloud_name=settings.cloudinary_cloud_name,
            api_key=settings.cloudinary_api_key,
            api_secret=settings.cloudinary_api_secret,
            secure=True,
        )
        _cloudinary_configured = True


def _extension_from_content_type(content_type: str | None, filename: str) -> str:
    if filename:
        ext = filename.rsplit(".", 1)[-1].lower()
        if ext in ALLOWED_EXTENSIONS:
            return f".{ext}"
    mapping = {
        "image/jpeg": ".jpg",
        "image/jpg": ".jpg",
        "image/png": ".png",
        "application/pdf": ".pdf",
    }
    return mapping.get(content_type or "", ".jpg")


async def submit_donation_application(uid: str, file: UploadFile) -> dict:
    db = get_firestore_client()

    # Reject if patient already has a pending/approved application
    existing = (
        db.collection(DONATION_COLLECTION)
        .where("patientUid", "==", uid)
        .where("status", "in", ["pending", "approved"])
        .limit(1)
        .get()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You already have an active donation application.",
        )

    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported file type. Use PDF, JPG, or PNG.",
        )

    file_bytes = await file.read()
    if len(file_bytes) > MAX_FILE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File too large. Maximum size is 10 MB.",
        )

    _configure_cloudinary()

    extension = _extension_from_content_type(file.content_type, file.filename or "")
    resource_type = "raw" if extension == ".pdf" else "image"

    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=extension) as tmp:
            tmp.write(file_bytes)
            temp_path = tmp.name

        result = cloudinary.uploader.upload(
            temp_path,
            folder=f"ayu/donations/{uid}",
            resource_type=resource_type,
        )
        file_url = result["secure_url"]
        public_id = result["public_id"]
        stored_filename = f"{public_id.split('/')[-1]}{extension}"
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to upload document: {exc}",
        ) from exc
    finally:
        if temp_path and os.path.exists(temp_path):
            os.unlink(temp_path)

    now = datetime.now(timezone.utc)
    doc_ref = db.collection(DONATION_COLLECTION).document()
    doc_ref.set({
        "patientUid": uid,
        "status": "pending",
        "approvedForDonation": False,
        "medicalDocument": {
            "url": file_url,
            "filename": file.filename or stored_filename,
        },
        "rejectionReason": None,
        "reviewedAt": None,
        "reviewedByUid": None,
        "createdAt": now,
        "updatedAt": now,
    })

    return {
        "applicationId": doc_ref.id,
        "status": "pending",
        "createdAt": now.isoformat(),
    }


def get_donation_status(uid: str) -> dict:
    db = get_firestore_client()

    docs = (
        db.collection(DONATION_COLLECTION)
        .where("patientUid", "==", uid)
        .get()
    )

    if not docs:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No donation application found.",
        )

    # Pick the most recent application in case the patient resubmitted after rejection
    latest = max(docs, key=lambda d: d.to_dict().get("createdAt") or datetime.min.replace(tzinfo=timezone.utc))
    data = latest.to_dict()
    doc_id = latest.id

    created_at = data.get("createdAt")
    updated_at = data.get("updatedAt")

    return {
        "applicationId": doc_id,
        "status": data.get("status", "pending"),
        "rejectionReason": data.get("rejectionReason"),
        "createdAt": created_at.isoformat() if hasattr(created_at, "isoformat") else str(created_at),
        "updatedAt": updated_at.isoformat() if hasattr(updated_at, "isoformat") else str(updated_at),
    }
