import logging
from pathlib import Path
from typing import Any

import firebase_admin
from fastapi import HTTPException, status
from firebase_admin import auth, credentials, firestore

from app.core.config import get_settings

logger = logging.getLogger(__name__)

# Build Firebase config from environment settings
def build_firebase_options() -> dict[str, Any]:
  settings = get_settings()
  options: dict[str, Any] = {}

  if settings.firebase_project_id:
    options["projectId"] = settings.firebase_project_id
  if settings.firebase_storage_bucket:
    options["storageBucket"] = settings.firebase_storage_bucket

  return options

# Initialize Firebase once when the app starts
def initialize_firebase() -> None:
  if firebase_admin._apps:
    return

  settings = get_settings()
  options = build_firebase_options()

  try:
    if settings.firebase_credentials_path:
      credential_path = Path(settings.firebase_credentials_path)
      if not credential_path.exists():
        raise FileNotFoundError(
          f"Firebase credentials file not found: {credential_path}"
        )

      cred = credentials.Certificate(str(credential_path))
      firebase_admin.initialize_app(credential=cred, options=options or None)
    else:
      firebase_admin.initialize_app(options=options or None)
  except Exception as exc: 
    logger.exception("Firebase initialization failed.")
    raise RuntimeError("Firebase initialization failed.") from exc

# Verify Firebase token and return decoded user data
def verify_firebase_token(id_token: str) -> dict[str, Any]:
  initialize_firebase()

  try:
    return auth.verify_id_token(
      id_token,
      check_revoked=False,
      clock_skew_seconds=60,
    )
  except Exception as exc: 
    logger.warning("Firebase token verification failed: %s", exc)
    raise HTTPException(
      status_code=status.HTTP_401_UNAUTHORIZED,
      detail="Invalid or expired Firebase token.",
    ) from exc

# Get Firestore database client
def get_firestore_client() -> firestore.Client:
  initialize_firebase()

  try:
    return firestore.client()
  except Exception as exc:  
    raise HTTPException(
      status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
      detail="Firestore is unavailable.",
    ) from exc