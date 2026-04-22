import asyncio
import functools

from fastapi import APIRouter, Depends, Query

from app.dependencies.auth import CurrentUser, require_patient_access
from app.schemas.video import (
    VideoInteractionRequest,
    VideoInteractionResponse,
    VideoRecommendationsResponse,
)
from app.services.video_recommendation_service import (
    get_video_recommendations,
    record_video_interaction,
)

router = APIRouter(prefix="/videos", tags=["videos"])


def _run_sync(func, *args):
    loop = asyncio.get_running_loop()
    return loop.run_in_executor(None, functools.partial(func, *args))


@router.get("/recommendations", response_model=VideoRecommendationsResponse)
async def fetch_video_recommendations(
    refresh: bool = Query(default=False),
    max_per_query: int = Query(default=2, ge=1, le=5),
    user: CurrentUser = Depends(require_patient_access),
) -> VideoRecommendationsResponse:
    items, meta = await _run_sync(get_video_recommendations, user.uid, refresh, max_per_query)

    return VideoRecommendationsResponse(
        generated_at=meta.get("generated_at"),
        cached=bool(meta.get("cached", False)),
        dominant_emotion=meta.get("dominant_emotion"),
        recommendation_mode=meta.get("recommendation_mode"),
        mood=str(meta.get("mood", "Normal")),
        mood_trend=str(meta.get("mood_trend", "Improving")),
        tags=list(meta.get("tags", [])),
        items=items,
    )


@router.post("/interactions", response_model=VideoInteractionResponse)
async def track_video_interaction(
    payload: VideoInteractionRequest,
    user: CurrentUser = Depends(require_patient_access),
) -> VideoInteractionResponse:
    if not payload.tags:
        return VideoInteractionResponse(status="ignored", updated_tags=None)

    try:
        updated = await _run_sync(record_video_interaction, user.uid, payload.tags)
    except Exception:
        return VideoInteractionResponse(status="error", updated_tags=None)

    return VideoInteractionResponse(status="ok", updated_tags=updated)
