from functools import lru_cache
from pydantic_settings import BaseSettings

# App settings loaded from environment variables
class Settings(BaseSettings):
    app_name: str = "AYU Backend API"
    api_prefix: str = "/api"
    cors_origins: list[str] = [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ]

    firebase_credentials_path: str | None = None
    firebase_project_id: str | None = None
    firebase_storage_bucket: str | None = None

    cloudinary_url: str | None = None
    cloudinary_cloud_name: str | None = None
    cloudinary_api_key: str | None = None
    cloudinary_api_secret: str | None = None

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "case_sensitive": False,
    }

# Cache settings so they are loaded only once
@lru_cache
def get_settings():
    return Settings()