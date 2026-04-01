from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.firebase import initialize_firebase


def create_app() -> FastAPI:
  settings = get_settings()
  app = FastAPI(title=settings.app_name)

  app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
  )
  # Initialize the Firebase once when the server starts
  @app.on_event("startup")
  def startup_event() -> None:
    initialize_firebase()
  # health check endpoint
  @app.get("/")
  def read_root() -> dict[str, str]:
    return {"message": f"{settings.app_name} is running"}

  return app

app = create_app()