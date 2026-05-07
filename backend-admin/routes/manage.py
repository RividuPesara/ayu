from fastapi import APIRouter, Depends, HTTPException, Request
from firebase_admin import firestore
from pydantic import BaseModel, Field
from typing import List, Optional
from auth import require_admin

router = APIRouter(tags=["Posts"])

db = firestore.client()

# MODELS
class ContentImage(BaseModel):
    id: str
    dataUrl: str
    name: str


class ArticleCreate(BaseModel):
    title: str
    genre: str
    author: str
    thumbnail: str
    content: str
    contentImages: Optional[List[ContentImage]] = Field(default_factory=list)


class ArticleUpdate(BaseModel):
    title: str
    genre: str
    author: str
    thumbnail: str
    content: str
    contentImages: Optional[List[ContentImage]] = Field(default_factory=list)


class StatusUpdate(BaseModel):
    published: bool


# GET ALL ARTICLES
@router.get("/")
def get_articles(user=Depends(require_admin)):
    docs = db.collection("articles").stream()

    articles = []
    for doc in docs:
        data = doc.to_dict()

        articles.append({
            "id": doc.id,
            "title": data.get("title", ""),
            "genre": data.get("genre", ""),
            "author": data.get("author", ""),
            "thumbnail": data.get("thumbnail", ""),
            "content": data.get("content", ""),
            "published": data.get("published", False),
            "contentImages": data.get("contentImages", []),
        })

    return articles


# CREATE ARTICLE
@router.post("/")
def create_article(article: ArticleCreate, user=Depends(require_admin)):
    try:
        doc_ref = db.collection("articles").document()

        data = {
            "title": article.title,
            "genre": article.genre,
            "author": article.author,
            "thumbnail": article.thumbnail,
            "content": article.content,
            "published": False,
            "contentImages": [img.dict() for img in article.contentImages] if article.contentImages else [],
        }

        doc_ref.set(data)

        return {
            "id": doc_ref.id,
            **data
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create article: {str(e)}")


# UPDATE ARTICLE
@router.patch("/{article_id}")
def update_article(article_id: str, payload: ArticleUpdate, user=Depends(require_admin)):
    doc_ref = db.collection("articles").document(article_id)
    snapshot = doc_ref.get()

    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Article not found")

    try:
        updated_data = {
            "title": payload.title,
            "genre": payload.genre,
            "author": payload.author,
            "thumbnail": payload.thumbnail,
            "content": payload.content,
            "contentImages": [img.dict() for img in payload.contentImages] if payload.contentImages else [],
        }

        doc_ref.update(updated_data)

        latest = doc_ref.get().to_dict()

        return {
            "id": article_id,
            **latest
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update article: {str(e)}")


# DELETE ARTICLE
@router.delete("/{article_id}")
def delete_article(article_id: str, user=Depends(require_admin)):
    doc_ref = db.collection("articles").document(article_id)
    snapshot = doc_ref.get()

    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Article not found")

    doc_ref.delete()

    return {"success": True}


# TOGGLE STATUS (Publish / Draft)
@router.patch("/{article_id}/status")
def update_status(article_id: str, payload: StatusUpdate, user=Depends(require_admin)):
    doc_ref = db.collection("articles").document(article_id)
    snapshot = doc_ref.get()

    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Article not found")

    doc_ref.update({
        "published": payload.published
    })

    return {"success": True}