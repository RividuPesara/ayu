from datetime import datetime

from pydantic import BaseModel

class VideoRecommendation(BaseModel):
    video_id: str
    title: str
    channel: str
    thumbnail: str
    url: str
    query_used: str
    tags: list[str] = []
    published_at: datetime | None = None
    view_count: int | None = None

class VideoRecommendationsResponse(BaseModel):
    generated_at: datetime | None = None
    cached: bool = False
    dominant_emotion: str | None = None
    recommendation_mode: str | None = None
    mood: str
    mood_trend: str
    tags: list[str]
    items: list[VideoRecommendation]

class VideoInteractionRequest(BaseModel):
    video_id: str
    tags: list[str] = []

class VideoInteractionResponse(BaseModel):
    status: str
    updated_tags: dict[str, int] | None = None
