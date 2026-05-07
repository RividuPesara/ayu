from fastapi import APIRouter, Depends
from firebase import db
from firebase_admin import firestore
from auth import require_admin

router = APIRouter()

def serialize_timestamp(ts):
    if ts:
        return {"seconds": int(ts.timestamp())}
    return None

@router.get("")
def get_posts(status: str | None = None, user=Depends(require_admin)):
    ref = db.collection("communityPosts")

    if status:
        docs = ref.where("status", "==", status).order_by(
            "createdAt", direction=firestore.Query.DESCENDING
        ).stream()
    else:
        docs = ref.order_by(
            "createdAt", direction=firestore.Query.DESCENDING
        ).stream()

    posts = []
    for d in docs:
        data = d.to_dict()
        data["id"] = d.id
        data["createdAt"] = serialize_timestamp(data.get("createdAt"))
        posts.append(data)

    return posts

@router.patch("/{post_id}/approve")
def approve_post(post_id: str, user=Depends(require_admin)):
    db.collection("communityPosts").document(post_id).update({
        "status": "approved",
        "moderatedAt": firestore.SERVER_TIMESTAMP,
    })
    return {"message": "Post approved"}

@router.patch("/{post_id}/reject")
def reject_post(post_id: str, user=Depends(require_admin)):
    db.collection("communityPosts").document(post_id).update({
        "status": "rejected",
        "moderatedAt": firestore.SERVER_TIMESTAMP,
    })
    return {"message": "Post rejected"}