from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr
from firebase_admin import auth, firestore

router = APIRouter()
db = firestore.client()

class ProfileResponse(BaseModel):
    uid: str
    firstName: Optional[str] = None
    lastName: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    avatar: Optional[str] = None
    role: Optional[str] = None


class UpdateProfileRequest(BaseModel):
    uid: str
    firstName: str
    lastName: str
    email: EmailStr
    phone: Optional[str] = None
    avatar: Optional[str] = None
    newPassword: Optional[str] = None


@router.get("/{uid}", response_model=ProfileResponse)
def get_profile(uid: str):
    doc_ref = db.collection("users").document(uid)
    doc = doc_ref.get()

    if not doc.exists:
        raise HTTPException(status_code=404, detail="Profile not found")

    data = doc.to_dict()

    return {
        "uid": uid,
        "firstName": data.get("firstName"),
        "lastName": data.get("lastName"),
        "email": data.get("email"),
        "phone": data.get("phone"),
        "avatar": data.get("avatar") or "",
        "role": data.get("role"),
    }


@router.put("/update")
def update_profile(payload: UpdateProfileRequest):
    uid = payload.uid

    doc_ref = db.collection("users").document(uid)
    doc = doc_ref.get()

    if not doc.exists:
        raise HTTPException(status_code=404, detail="Profile not found")

    update_data = {
        "firstName": payload.firstName,
        "lastName": payload.lastName,
        "email": payload.email,
        "avatar": payload.avatar if payload.avatar else "",
    }

    if payload.phone:
        update_data["phone"] = payload.phone.strip()

    doc_ref.update(update_data)

    try:
        update_data = {
            "email": payload.email,
        }

        if payload.newPassword and payload.newPassword.strip():
            update_data["password"] = payload.newPassword

        auth.update_user(uid, **update_data)

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Auth update failed: {str(e)}"
        )

    return {"message": "Profile updated successfully"}