from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes.feed import router as feed_router
from routes.moderation import router as moderation_router
from routes.posts import router as posts_router
from routes.documents import router as documents_router
from routes.profile import router as profile_router

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(feed_router, prefix="/api/feed")
app.include_router(moderation_router, prefix="/api/moderation/posts")
app.include_router(posts_router, prefix="/api/posts")
app.include_router(documents_router, prefix="/api/documents", tags=["Documents"])
app.include_router(profile_router, prefix="/api/profile", tags=["Profile"])
