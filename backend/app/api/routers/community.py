from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from app.dependencies.auth import get_current_user, CurrentUser
from app.schemas.community import CreatePostRequest, AddCommentRequest
from app.services.community_service import (
    get_all_approved_posts,
    get_my_posts,
    create_community_post,
    toggle_post_like,
    get_post_comments,
    add_post_comment,
    upload_image_to_cloudinary,
)

# Router setup with prefix
router = APIRouter(prefix="/community", tags=["Community"])

# Upload image to Cloudinary
@router.post("/upload-image")
async def upload_image(
    file: UploadFile = File(...),
    user: CurrentUser = Depends(get_current_user),
):
    image_url = await upload_image_to_cloudinary(file)
    return {"imageURL": image_url}

# Get all approved posts
@router.get("/posts")
def get_posts(user: CurrentUser = Depends(get_current_user)):
    return get_all_approved_posts(user.uid)

# Get current user posts
@router.get("/posts/mine")
def get_my_community_posts(user: CurrentUser = Depends(get_current_user)):
    return get_my_posts(user.uid)

# Create posts
@router.post("/posts")
def create_post(data: CreatePostRequest, user: CurrentUser = Depends(get_current_user)):
    post_id = create_community_post(
        uid=user.uid,
        post_type=data.type,
        caption=data.caption or "",
        imageURL=data.imageURL or "",
        text=data.text or "",
        title=data.title or "",
        content=data.content or "",
    )

    return {
        "message": "Post created successfully",
        "postId": post_id,
    }

# Like/unlike post
@router.post("/posts/{post_id}/like")
def like_post(post_id: str, user: CurrentUser = Depends(get_current_user)):
    result = toggle_post_like(post_id, user.uid)

    if result is None:
        raise HTTPException(status_code=404, detail="Post not found")

    return result

# Get comments for post
@router.get("/posts/{post_id}/comments")
def get_comments(post_id: str, user: CurrentUser = Depends(get_current_user)):
    return get_post_comments(post_id)

# Add comment to post
@router.post("/posts/{post_id}/comments")
def add_comment(
    post_id: str,
    data: AddCommentRequest,
    user: CurrentUser = Depends(get_current_user),
):
    comment_id = add_post_comment(post_id, user.uid, data.text)

    if comment_id is None:
        raise HTTPException(status_code=404, detail="Post not found")

    return {
        "message": "Comment added successfully",
        "commentId": comment_id,
    }