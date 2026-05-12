from fastapi import HTTPException, status
from app.core.firebase import get_firestore_client

db = get_firestore_client()

def _format_article(doc) -> dict:
    data = doc.to_dict()
    raw_images = data.get("contentImages") or []
    return {
        "id": doc.id,
        "title": data.get("title", ""),
        "genre": data.get("genre", ""),
        "author": data.get("author", ""),
        "thumbnail": data.get("thumbnail", ""),
        "content": data.get("content", ""),
        "contentImages": [
            {
                "id": img.get("id", ""),
                "dataUrl": img.get("dataUrl", ""),
                "name": img.get("name", ""),
            }
            for img in raw_images
            if isinstance(img, dict)
        ],
    }

def get_published_articles() -> list[dict]:
    docs = (
        db.collection("articles")
        .where("published", "==", True)
        .stream()
    )
    return [_format_article(doc) for doc in docs]

def get_article_by_id(article_id: str) -> dict:
    doc = db.collection("articles").document(article_id).get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Article not found.")
    data = doc.to_dict()
    if not data.get("published", False):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Article not found.")
    return _format_article(doc)
