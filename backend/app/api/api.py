from fastapi import APIRouter

from app.api.routers import auth, doctor, chatbot, videos ,journal

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(doctor.router)
api_router.include_router(chatbot.router)
api_router.include_router(videos.router)
api_router.include_router(journal.router)
