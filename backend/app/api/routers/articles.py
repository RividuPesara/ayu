import asyncio
import functools

from fastapi import APIRouter, Depends

from app.dependencies.auth import CurrentUser, require_patient_or_companion_access
from app.schemas.article import ArticleListResponse, ArticleResponse
from app.services.article_service import get_article_by_id, get_published_articles

router = APIRouter(prefix="/articles", tags=["articles"])

def _run_sync(func, *args):
    loop = asyncio.get_running_loop()
    return loop.run_in_executor(None, functools.partial(func, *args))

@router.get("", response_model=ArticleListResponse)
async def list_articles(user: CurrentUser = Depends(require_patient_or_companion_access),
) -> ArticleListResponse:
    articles = await _run_sync(get_published_articles)
    return ArticleListResponse(articles=articles, total=len(articles))

@router.get("/{article_id}", response_model=ArticleResponse)
async def get_article(article_id: str, user: CurrentUser = Depends(require_patient_or_companion_access),) -> ArticleResponse:
    return await _run_sync(get_article_by_id, article_id)
