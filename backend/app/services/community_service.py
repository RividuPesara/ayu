from app.core.firebase import get_firestore_client
from firebase_admin import firestore
from datetime import datetime, timezone
import os
import tempfile
import cloudinary
import cloudinary.uploader
from fastapi import UploadFile, HTTPException, status
from app.core.config import get_settings

db = get_firestore_client()

# Get user details
def get_user_details(uid: str):
    user_doc = db.collection("users").document(uid).get()

    if not user_doc.exists:
        return {
            "authorName": "User",
            "authorAvatar": "",
        }

    data = user_doc.to_dict()

    first_name = data.get("firstName", "")
    last_name = data.get("lastName", "")
    full_name = data.get("fullName") or f"{first_name} {last_name}".strip() or "User"

    return {
        "authorName": full_name,
        "authorAvatar": data.get("avatar") or data.get("photoURL") or "",
    }

# Format timestamp
def serialize_created_at(value):
    if value is None:
        return None

    if hasattr(value, "timestamp"):
        return {"seconds": int(value.timestamp())}

    return None

# Format post
def format_post(doc, current_uid: str = ""):
    data = doc.to_dict()
    liked_by = data.get("likedBy", [])

    return {
        "id": data.get("id") or doc.id,
        "type": data.get("type", ""),
        "authorId": data.get("authorId", ""),
        "authorName": data.get("authorName", "User"),
        "authorHandle": data.get("authorHandle", ""),
        "authorAvatar": data.get("authorAvatar", ""),

        "text": data.get("text", ""),
        "caption": data.get("caption", ""),
        "title": data.get("title", ""),
        "content": data.get("content", ""),
        "imageURL": data.get("imageURL", ""),

        "likeCount": data.get("likeCount", 0),
        "likedBy": liked_by,
        "commentCount": data.get("commentCount", 0),

        "status": data.get("status", "pending"),
        "createdAt": serialize_created_at(data.get("createdAt")),

        "isLiked": current_uid in liked_by,
        "isMine": data.get("authorId") == current_uid,
    }

# Get all approved posts
def get_all_approved_posts(current_uid: str):
    posts_ref = (
        db.collection("communityPosts")
        .where("status", "==", "approved")
        .order_by("createdAt", direction=firestore.Query.DESCENDING)
        .stream()
    )

    return [format_post(doc, current_uid) for doc in posts_ref]

# Get user posts
def get_my_posts(uid: str):
    posts_ref = (
        db.collection("communityPosts")
        .where("authorId", "==", uid)
        .order_by("createdAt", direction=firestore.Query.DESCENDING)
        .stream()
    )

    return [format_post(doc, uid) for doc in posts_ref]

# Create post
def create_community_post(
    uid: str,
    post_type: str,
    caption: str = "",
    imageURL: str = "",
    text: str = "",
    title: str = "",
    content: str = "",
):
    user = get_user_details(uid)

    post_data = {
        "id": "",
        "type": post_type,
        "authorId": uid,
        "authorName": user["authorName"],
        "authorHandle": "",
        "authorAvatar": user["authorAvatar"],

        "text": text,
        "caption": caption,
        "title": title,
        "content": content,
        "imageURL": imageURL or "",

        "status": "pending",
        "likeCount": 0,
        "likedBy": [],
        "commentCount": 0,
        "createdAt": datetime.now(timezone.utc),
    }

    doc_ref = db.collection("communityPosts").document()
    post_data["id"] = doc_ref.id
    doc_ref.set(post_data)

    return doc_ref.id

# Like/unlike post
def toggle_post_like(post_id: str, uid: str):
    post_ref = db.collection("communityPosts").document(post_id)
    post_doc = post_ref.get()

    if not post_doc.exists:
        return None

    data = post_doc.to_dict()
    liked_by = data.get("likedBy", [])

    if uid in liked_by:
        liked_by.remove(uid)
        liked = False
    else:
        liked_by.append(uid)
        liked = True

    post_ref.update({
        "likedBy": liked_by,
        "likeCount": len(liked_by),
    })

    return {
        "liked": liked,
        "likeCount": len(liked_by),
    }

# Get comments
def get_post_comments(post_id: str):
    comments_ref = (
        db.collection("communityPosts")
        .document(post_id)
        .collection("comments")
        .order_by("createdAt")
        .stream()
    )

    comments = []

    for doc in comments_ref:
        data = doc.to_dict()
        comments.append({
            "id": doc.id,
            "uid": data.get("uid", ""),
            "authorName": data.get("authorName", "User"),
            "authorAvatar": data.get("authorAvatar", ""),
            "text": data.get("text", ""),
            "createdAt": serialize_created_at(data.get("createdAt")),
        })

    return comments

# Add comment
def add_post_comment(post_id: str, uid: str, text: str):
    post_ref = db.collection("communityPosts").document(post_id)
    post_doc = post_ref.get()

    if not post_doc.exists:
        return None

    user = get_user_details(uid)

    comment_data = {
        "uid": uid,
        "authorName": user["authorName"],
        "authorAvatar": user["authorAvatar"],
        "text": text,
        "createdAt": datetime.now(timezone.utc),
    }

    comment_ref = post_ref.collection("comments").document()
    comment_ref.set(comment_data)

    post_ref.update({
        "commentCount": firestore.Increment(1),
    })

    return comment_ref.id

# Upload image to cloudinary
async def upload_image_to_cloudinary(file: UploadFile) -> str:
    settings = get_settings()

    if not settings.cloudinary_cloud_name or not settings.cloudinary_upload_preset:
        raise HTTPException(
            status_code=500,
            detail="Cloudinary environment variables are missing",
        )

    cloudinary.config(
        cloud_name=settings.cloudinary_cloud_name,
        api_key=settings.cloudinary_api_key,
        api_secret=settings.cloudinary_api_secret,
        secure=True,
    )

    file_bytes = await file.read()

    if not file_bytes:
        raise HTTPException(status_code=400, detail="File is empty")

    extension = ".jpg"

    if file.content_type == "image/png":
        extension = ".png"
    elif file.content_type == "image/webp":
        extension = ".webp"
    elif file.content_type == "application/pdf":
        extension = ".pdf"

    temp_path = None

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=extension) as temp_file:
            temp_file.write(file_bytes)
            temp_path = temp_file.name

        result = cloudinary.uploader.upload(
            temp_path,
            folder="communityPosts",
            resource_type="image",
        )

    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"Cloudinary upload failed: {e}",
        )

    finally:
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)

    secure_url = result.get("secure_url")

    if not secure_url:
        raise HTTPException(
            status_code=502,
            detail="Cloudinary did not return URL",
        )

    return secure_url