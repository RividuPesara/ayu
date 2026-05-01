import logging
import os
from functools import lru_cache
from pathlib import Path
from pydantic import Field
from pydantic_settings import BaseSettings

logger = logging.getLogger(__name__)

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

    # Provider selection gemini or ollama
    chatbot_provider: str = "gemini"
    video_provider: str = "ollama"

    redis_url: str | None = None

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


def validate_startup_config() -> None:
    # Check required env vars and raise early
    settings = get_settings()
    errors: list[str] = []
    warnings: list[str] = []

    # irebase always required
    if not settings.firebase_project_id:
        errors.append("FIREBASE_PROJECT_ID is not set")
    if not settings.firebase_credentials_path:
        errors.append("FIREBASE_CREDENTIALS_PATH is not set")
    elif not Path(settings.firebase_credentials_path).exists():
        errors.append(
            f"FIREBASE_CREDENTIALS_PATH points to a file that does not exist: "
            f"'{settings.firebase_credentials_path}'"
        )

    # Sentiment models always required
    for model_file in ("lr_model.pkl", "bnb_model.pkl", "xgb_model.pkl", "vectorizer.pkl", "label_encoder.pkl"):
        full_path = os.path.join(settings.model_dir, model_file)
        if not os.path.exists(full_path):
            errors.append(f"Sentiment model file missing: '{full_path}' (check MODEL_DIR)")

    # Chatbot provider
    provider = settings.chatbot_provider.lower()
    if provider == "gemini":
        if not settings.gemini_api_key:
            errors.append("GEMINI_API_KEY is not set required when CHATBOT_PROVIDER=gemini)")
    elif provider == "ollama":
        if not settings.ollama_host:
            errors.append("OLLAMA_HOST is not set required when CHATBOT_PROVIDER=ollama")
    else:
        errors.append(f"CHATBOT_PROVIDER='{settings.chatbot_provider}' is invalid — must be 'gemini' or 'ollama'")

    # video provider
    video_prov = settings.video_provider.lower()
    if video_prov == "ollama" and not settings.ollama_host:
        if not any("OLLAMA_HOST" in e for e in errors):
            errors.append("OLLAMA_HOST is not set required when VIDEO_PROVIDER=ollama")
    elif video_prov == "gemini" and not settings.gemini_api_key:
        if not any("GEMINI_API_KEY" in e for e in errors):
            errors.append("GEMINI_API_KEY is not set required when VIDEO_PROVIDER=gemini")

    # warn if missing
    if not settings.youtube_api_key:
        warnings.append("YOUTUBE_API_KEY is not set video recommendations will be disabled")
    if not settings.redis_url:
        warnings.append("REDIS_URL is not set running in degraded mode (no caching, no distributed locks)")
    if not all([settings.zoom_account_id, settings.zoom_client_id, settings.zoom_client_secret]):
        warnings.append("Zoom credentials incomplete appointment video calls will not work")
    if not settings.cloudinary_url:
        warnings.append("CLOUDINARY_URL is not set profile photo uploads will not work")

    for w in warnings:
        logger.warning("[config] %s", w)

    if errors:
        bullet_list = "\n  - ".join(errors)
        raise RuntimeError(
            f"Startup aborted {len(errors)} configuration error found\n  - {bullet_list}"
        )