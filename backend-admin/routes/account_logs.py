from fastapi import APIRouter, Depends, HTTPException
from firebase_admin import auth, firestore
from auth import require_admin
from datetime import datetime
from zoneinfo import ZoneInfo

router = APIRouter()
db = firestore.client()

DEFAULT_PROFILE_IMAGE = "https://res.cloudinary.com/duysmfmo4/image/upload/v1776949962/human_r37ozb.jpg"
LOCAL_TIMEZONE = ZoneInfo("Asia/Colombo")


def format_date_time(timestamp_ms):
    if not timestamp_ms:
        return "Never logged in"

    date_time = datetime.fromtimestamp(timestamp_ms / 1000, tz=LOCAL_TIMEZONE)
    now = datetime.now(LOCAL_TIMEZONE)

    if date_time.date() == now.date():
        difference = now - date_time
        seconds = int(difference.total_seconds())
        minutes = seconds // 60
        hours = minutes // 60

        if seconds < 60:
            return "Just now"

        if minutes < 60:
            return f"{minutes} minute{'s' if minutes != 1 else ''} ago"

        return f"{hours} hour{'s' if hours != 1 else ''} ago"

    return date_time.strftime("%b %d, %Y %I:%M %p")


@router.get("/")
def get_account_logs(user=Depends(require_admin)):
    try:
        users = []
        page = auth.list_users()

        while page:
            for firebase_user in page.users:
                uid = firebase_user.uid

                user_doc = db.collection("users").document(uid).get()
                firestore_data = user_doc.to_dict() if user_doc.exists else {}

                first_name = firestore_data.get("firstName", "")
                last_name = firestore_data.get("lastName", "")
                full_name = firestore_data.get("fullName")

                name = full_name or f"{first_name} {last_name}".strip()

                if not name:
                    name = firebase_user.display_name or "Unknown User"

                role = firestore_data.get("role", "patient")

                role_map = {
                    "patient": "Patient",
                    "companion": "Companion",
                    "doctor": "Doctor",
                    "admin": "Admin",
                }

                avatar = (
                    firestore_data.get("avatar")
                    or firestore_data.get("photoURL")
                    or firebase_user.photo_url
                    or DEFAULT_PROFILE_IMAGE
                )

                users.append({
                    "id": uid,
                    "name": name,
                    "email": firebase_user.email or "No email",
                    "type": role_map.get(role.lower(), "Patient"),
                    "avatar": avatar,
                    "createdAt": format_date_time(firebase_user.user_metadata.creation_timestamp),
                    "lastLogin": format_date_time(firebase_user.user_metadata.last_sign_in_timestamp),
                })

            page = page.get_next_page()

        return users

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))