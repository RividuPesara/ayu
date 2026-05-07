from fastapi import APIRouter, Depends
from firebase_admin import firestore, auth
from auth import require_admin
from datetime import datetime, timedelta, timezone

router = APIRouter()
db = firestore.client()

def get_last_7_days():
    today = datetime.now(timezone.utc)
    days = []

    for i in range(6, -1, -1):
        day = today - timedelta(days=i)
        days.append({
            "key": day.strftime("%Y-%m-%d"),
            "label": day.strftime("%b %d"),
            "Patients": 0,
            "Companions": 0,
            "Doctors": 0,
        })

    return days

def get_auth_created_date(uid: str):
    try:
        user_record = auth.get_user(uid)

        created_ms = user_record.user_metadata.creation_timestamp

        if not created_ms:
            return None

        created_date = datetime.fromtimestamp(
            created_ms / 1000,
            tz=timezone.utc
        )

        return created_date.strftime("%Y-%m-%d")

    except Exception:
        return None

@router.get("/")
def get_dashboard_stats(user=Depends(require_admin)):

    admin_uid = user.get("uid")
    admin_doc = db.collection("users").document(admin_uid).get()

    admin_name = "Admin"

    if admin_doc.exists:
        
        admin_data = admin_doc.to_dict()
        first_name = admin_data.get("firstName", "")

        admin_name = first_name or "Admin"

    patients = list(
        db.collection("users")
        .where("role", "==", "patient")
        .stream()
    )

    companions = list(
        db.collection("users")
        .where("role", "==", "companion")
        .stream()
    )

    doctors = list(
        db.collection("users")
        .where("role", "==", "doctor")
        .stream()
    )

    pending_posts = list(
        db.collection("communityPosts")
        .where("status", "==", "pending")
        .stream()
    )

    pending_docs = list(
        db.collection("donationApplications")
        .where("status", "==", "pending")
        .stream()
    )

    new_users = get_last_7_days()
    day_map = {day["key"]: day for day in new_users}

    for doc in patients:
        data = doc.to_dict()
        uid = data.get("uid", doc.id)

        created_date = get_auth_created_date(uid)

        if created_date in day_map:
            day_map[created_date]["Patients"] += 1

    for doc in companions:
        data = doc.to_dict()
        uid = data.get("uid", doc.id)

        created_date = get_auth_created_date(uid)

        if created_date in day_map:
            day_map[created_date]["Companions"] += 1

    for doc in doctors:
        data = doc.to_dict()
        uid = data.get("uid", doc.id)

        created_date = get_auth_created_date(uid)

        if created_date in day_map:
            day_map[created_date]["Doctors"] += 1

    chart_data = [
        {
            "date": day["label"],
            "Patients": day["Patients"],
            "Companions": day["Companions"],
            "Doctors": day["Doctors"],
        }
        for day in new_users
    ]

    return {
        "adminName": admin_name,
        "stats": {
            "totalPatients": len(patients),
            "totalCompanions": len(companions),
            "totalDoctors": len(doctors),
            "postsToApprove": len(pending_posts),
            "documentsToReview": len(pending_docs),
        },
        "newUsers": chart_data,
    }