from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

from app.core.firebase import verify_firebase_token
from app.services.user_service import detect_user_role, extract_uid_from_token

bearer_scheme = HTTPBearer(auto_error=False)

class CurrentUser(BaseModel):
  uid: str
  email: str | None = None
  role: str = "user"
  full_name: str | None = None

# Extract and build the current user from the authorization token
async def get_current_user(
  credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> CurrentUser:
  if credentials is None:
    raise HTTPException(
      status_code=status.HTTP_401_UNAUTHORIZED,
      detail="Missing Authorization header.",
    )

  decoded_token = verify_firebase_token(credentials.credentials)
  uid = extract_uid_from_token(decoded_token)

  role = detect_user_role(uid)
  email = decoded_token.get("email")
  full_name = decoded_token.get("name")

  return CurrentUser(uid=uid, email=email, role=role, full_name=full_name)

# Allow only users with doctor role
async def require_doctor_user(
  user: Annotated[CurrentUser, Depends(get_current_user)],
) -> CurrentUser:
  if user.role != "doctor":
    raise HTTPException(
      status_code=status.HTTP_403_FORBIDDEN,
      detail="Doctor role required.",
    )
  return user

async def require_doctor_access(
  user: Annotated[CurrentUser, Depends(require_doctor_user)],
) -> CurrentUser:
  return user