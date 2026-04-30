from fastapi import APIRouter, Depends, HTTPException, Request
from firebase_admin import firestore
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from auth import require_admin

router = APIRouter(tags=["Articles"])
db = firestore.client()

# Models

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
    contentImages: Optional[List[ContentImage]] = []


class ArticleUpdate(BaseModel):
    title: str
    genre: str
    author: str
    thumbnail: str
    content: str
    contentImages: Optional[List[ContentImage]] = []


# Routes

@router.get("/")
def get_articles(user=Depends(require_admin)):
    docs = db.collection("articles").order_by("createdAt", direction=firestore.Query.DESCENDING).stream()

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
            "contentImages": data.get("contentImages", []),
            "createdAt": data.get("createdAt"),
        })

    return articles


@router.post("/")
def create_article(payload: ArticleCreate, user=Depends(require_admin)):
    try:
        article_data = {
            "title": payload.title,
            "genre": payload.genre,
            "author": payload.author,
            "thumbnail": payload.thumbnail,
            "content": payload.content,
            "contentImages": [img.dict() for img in payload.contentImages] if payload.contentImages else [],
            "createdAt": datetime.utcnow(),
        }

        doc_ref = db.collection("articles").document()
        doc_ref.set(article_data)

        return {
            "id": doc_ref.id,
            **article_data
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create article: {str(e)}")


@router.get("/{article_id}")
def get_single_article(article_id: str, user=Depends(require_admin)):
    doc_ref = db.collection("articles").document(article_id)
    snapshot = doc_ref.get()

    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Article not found")

    data = snapshot.to_dict()

    return {
        "id": article_id,
        **data
    }


@router.patch("/{article_id}")
def update_article(article_id: str, payload: ArticleUpdate, user=Depends(require_admin)):
    doc_ref = db.collection("articles").document(article_id)
    snapshot = doc_ref.get()

    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Article not found")

    updated_data = {
        "title": payload.title,
        "genre": payload.genre,
        "author": payload.author,
        "thumbnail": payload.thumbnail,
        "content": payload.content,
        "contentImages": [img.dict() for img in payload.contentImages] if payload.contentImages else [],
        "updatedAt": datetime.utcnow(),
    }

    doc_ref.update(updated_data)

    latest = doc_ref.get().to_dict()

    return {
        "id": article_id,
        **latest
    }


@router.delete("/{article_id}")
def delete_article(article_id: str, user=Depends(require_admin)):
    doc_ref = db.collection("articles").document(article_id)
    snapshot = doc_ref.get()

    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Article not found")

    doc_ref.delete()

    return {"success": True}