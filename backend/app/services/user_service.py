from typing import Any

from fastapi import HTTPException, status

from app.core.firebase import get_firestore_client

DOCTORS_COLLECTION = "doctors"

# Get user ID from Firebase token
def extract_uid_from_token(decoded_token: dict[str, Any]) -> str:
  uid = decoded_token.get("uid")
  if not isinstance(uid, str) or not uid.strip():
    raise HTTPException(
      status_code=status.HTTP_401_UNAUTHORIZED,
      detail="Token payload does not include user id.",
    )
  return uid


# Check Firestore for the user's role check
def detect_user_role(uid: str) -> str:
  db = get_firestore_client()
  snapshot = db.collection(DOCTORS_COLLECTION).document(uid).get()

  if not snapshot.exists:
    return "user"

  data = snapshot.to_dict() or {}
  raw_role = data.get("role")
  if isinstance(raw_role, str) and raw_role.strip():
    return raw_role.strip().lower()

  return "doctor"