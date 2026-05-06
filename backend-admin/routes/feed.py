from fastapi import APIRouter, WebSocket, Depends
from firebase import db
from firebase_admin import firestore
from datetime import datetime
from websocket import broadcast, connect, disconnect
from auth import verify_token

router = APIRouter()

def serialize_timestamp(ts):
    if ts:
        return {"seconds": int(ts.timestamp())}
    return None

# Get all approved posts
@router.get("/")
def get_posts():
    docs = (
        db.collection("communityPosts")
        .where("status", "==", "approved")
        .order_by("createdAt", direction=firestore.Query.DESCENDING)
        .stream()
    )

    posts = []

    for d in docs:
        data = d.to_dict()
        data["id"] = d.id

        data["createdAt"] = serialize_timestamp(data.get("createdAt"))
        data["commentCount"] = data.get("commentCount", 0)
        data["likeCount"] = data.get("likeCount", 0)
        data["likedBy"] = data.get("likedBy", [])

        posts.append(data)

    return posts

# Get comments
@router.get("/{post_id}/comments")
def get_comments(post_id: str):
    docs = (
        db.collection("communityPosts")
        .document(post_id)
        .collection("comments")
        .order_by("createdAt", direction=firestore.Query.DESCENDING)  
        .stream()
    )

    comments = []

    for d in docs:
        data = d.to_dict()

        comments.append({
            "id": d.id,
            "authorId": data.get("authorId", ""),
            "authorName": data.get("authorName", "Anonymous"),
            "authorAvatar": data.get("authorAvatar", ""),
            "text": data.get("text", ""),
            "createdAt": serialize_timestamp(data.get("createdAt"))
        })

    return comments

# Like / Unlike post
@router.post("/{post_id}/like")
async def like_post(post_id: str, user=Depends(verify_token)):

    userId = user['uid']

    ref = db.collection("communityPosts").document(post_id)
    doc = ref.get()

    data = doc.to_dict()
    liked_by = data.get("likedBy", [])

    if userId in liked_by:
        liked_by.remove(userId)
        like_count = data.get("likeCount", 0) - 1
    else:
        liked_by.append(userId)
        like_count = data.get("likeCount", 0) + 1

    ref.update({
        "likedBy": liked_by,
        "likeCount": like_count
    })

    await broadcast({
        "type": "like",
        "postId": post_id,
        "likeCount": like_count,
        "likedBy": liked_by
    })

    return {"success": True}

# Add comment
@router.post("/{post_id}/comment")
async def add_comment(post_id: str, text: str, user=Depends(verify_token)):

    userId = user['uid']

    ref = db.collection("communityPosts").document(post_id)

    comment_ref = ref.collection("comments").document()

    user_doc = db.collection("users").document(userId).get()
    user_data = user_doc.to_dict() or {}

    authorName = (
        user_data.get("fullName")
        or f"{user_data.get('firstName', '')} {user_data.get('lastName', '')}".strip()
        or user.get("name")
        or "Anonymous"
    )

    authorAvatar = (
        user_data.get("avatar")
        or user_data.get("photoURL")
        or ""
    )

    comment_ref.set({
        "authorId": userId,
        "authorName": authorName,
        "authorAvatar": authorAvatar,
        "text": text,
        "createdAt": datetime.utcnow()
    })

    ref.update({
        "commentCount": firestore.Increment(1)
    })

    updated_doc = ref.get().to_dict()

    await broadcast({
        "type": "comment",
        "postId": post_id,
        "commentCount": updated_doc.get("commentCount", 0)
    })

    return {"success": True}

# WebSocket
@router.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    uid = await connect(ws)

    if not uid:
        return

    try:
        while True:
            await ws.receive_text()
    except Exception:
        await disconnect(ws)