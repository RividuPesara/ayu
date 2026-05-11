from pydantic import BaseModel
from typing import Optional

class ContentImage(BaseModel):
    id: str
    dataUrl: str
    name: str

class ArticleResponse(BaseModel):
    id: str
    title: str
    genre: str
    author: str
    thumbnail: str
    content: str
    contentImages: list[ContentImage] = []

class ArticleListResponse(BaseModel):
    articles: list[ArticleResponse]
    total: int
