from fastapi import APIRouter, Depends
from firebase import db
from datetime import datetime
from auth import verify_token

router = APIRouter()

@router.post("/create")
async def create_post(data: dict, decoded_token: dict = Depends(verify_token)):
    uid = decoded_token["uid"]

    post = {
        "type": data.get("type"),
        "imageURL": data.get("imageURL", ""),
        "text": data.get("text", ""),
        "caption": data.get("caption", ""),
        "title": data.get("title", ""),
        "content": data.get("content", ""),
        "authorId": uid,
        "authorName": data.get("authorName", "Admin"),
        "status": "pending",
        "createdAt": datetime.utcnow(),
    }

    db.collection("communityPosts").add(post)

    return {"message": "Post created"}