from typing import Any

from cachetools import TTLCache
from fastapi import HTTPException, status

from app.core.firebase import get_firestore_client

USERS_COLLECTION = "users"

_role_cache: TTLCache[str, str] = TTLCache(maxsize=256, ttl=300) #cache 256 users and keep them for 5 mins if max reach , remove the least used entry


# Get user ID from Firebase token
def extract_uid_from_token(decoded_token: dict[str, Any]) -> str:
  uid = decoded_token.get("uid")
  if not isinstance(uid, str) or not uid.strip():
    raise HTTPException(
      status_code=status.HTTP_401_UNAUTHORIZED,
      detail="Token payload does not include user id.",
    )
  return uid



# Check Firestore for the user's role and cached for 5 minutes
def detect_user_role(uid: str) -> str:
  cached = _role_cache.get(uid)
  if cached is not None:
    return cached

  db = get_firestore_client()
  snapshot = db.collection(USERS_COLLECTION).document(uid).get()

  if not snapshot.exists:
    _role_cache[uid] = "user"
    return "user"

  data = snapshot.to_dict() or {}
  raw_role = data.get("role")
  if isinstance(raw_role, str) and raw_role.strip():
    role = raw_role.strip().lower()
    _role_cache[uid] = role
    return role

  doctor_profile = data.get("doctorProfile")
  if isinstance(doctor_profile, dict) and doctor_profile:
    _role_cache[uid] = "doctor"
    return "doctor"

  patient_profile = data.get("patientProfile")
  if isinstance(patient_profile, dict) and patient_profile:
    _role_cache[uid] = "patient"
    return "patient"

  _role_cache[uid] = "user"
  return "user"