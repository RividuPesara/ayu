from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from firebase_admin import firestore

router = APIRouter()
db = firestore.client()


class AdminVerifyRequest(BaseModel):
    uid: str


@router.post("/verify-admin")
def verify_admin(data: AdminVerifyRequest):
    user_doc = db.collection("users").document(data.uid).get()

    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User not found in users collection")

    user_data = user_doc.to_dict()
    role = user_data.get("role", "").lower()

    if role != "admin":
        raise HTTPException(status_code=403, detail="Access denied: you are not an admin")

    return {
        "message": "Admin verified successfully",
        "uid": data.uid,
        "role": user_data.get("role"),
    }
