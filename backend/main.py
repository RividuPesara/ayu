from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.firebase import initialize_firebase
from app.core.chatbot_engine import initialize_chatbot_engine
from app.services.sentiment_service import initialize_sentiment_service
from app.api.api import api_router

def create_app() -> FastAPI:
  settings = get_settings()
  app = FastAPI(title=settings.app_name)

  # allow dynamic ports for local development and testing since flutter web uses random ports
  app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
  )
  # Initialize Firebase, sentiment models, and chatbot engine once when the server starts
  @app.on_event("startup")
  def startup_event() -> None:
    initialize_firebase()
    initialize_sentiment_service(settings.model_dir)
    if settings.gemini_api_key:
      initialize_chatbot_engine(
        gemini_api_key = settings.gemini_api_key,
        chroma_db_dir = settings.chroma_db_dir,
        knowledge_base_path = settings.knowledge_base_path,
        hf_token= settings.hf_token,
      )
  # health check endpoint
  @app.get("/")
  def read_root() -> dict[str, str]:
    return {"message": f"{settings.app_name} is running"}

  app.include_router(api_router, prefix=settings.api_prefix)
  return app

app = create_app()