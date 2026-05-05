from functools import lru_cache
from pydantic import Field
from pydantic_settings import BaseSettings

# App settings loaded from environment variables
class Settings(BaseSettings):
    app_name: str = "AYU Backend API"
    api_prefix: str = "/api"
    dashboard_timezone: str = "Asia/Colombo"
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
    cloudinary_upload_preset: str | None = None

    gemini_api_key: str | None = None
    hf_token: str | None = None
    model_dir: str = "../models"
    chroma_db_dir: str = "../data/chroma_db"
    knowledge_base_path: str = "../data/cancer_knowledge_base.json"

    zoom_account_id: str | None = None
    zoom_client_id: str | None = None
    zoom_client_secret: str | None = None
    zoom_user_id: str | None = None
    appointment_duration_minutes: int = 30
    youtube_api_key: str | None = None
    ollama_cf_client_id: str | None = None
    ollama_cf_client_secret: str | None = None
    ollama_host: str | None = None
    ollama_model: str = Field(default="qwen3.5:9b", validation_alias="MODEL")

    dev_mode: bool = False
    dev_patient_uid: str = "dev-rividu-pesara"
    dev_patient_email: str = "rivindupeshara11@gmail.com"
    dev_patient_name: str = "Rividu Pesara"
    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "case_sensitive": False,
    }

# Cache settings so they are loaded only once
@lru_cache
def get_settings():
    return Settings()