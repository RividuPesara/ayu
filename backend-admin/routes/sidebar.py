from fastapi import APIRouter, Depends, HTTPException
from firebase_admin import firestore
from auth import require_admin

router = APIRouter()
db = firestore.client()

@router.get("/{uid}")
def get_sidebar_user(uid: str, user=Depends(require_admin)):
    user_doc = db.collection("users").document(uid).get()

    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User not found")

    data = user_doc.to_dict()

    full_name = data.get("fullName")

    if not full_name:
        first_name = data.get("firstName", "")
        last_name = data.get("lastName", "")
        full_name = f"{first_name} {last_name}".strip()

    return {
        "uid": uid,
        "name": full_name or "Admin",
        "email": data.get("email", ""),
        "avatar": data.get("avatar") or "",
    }