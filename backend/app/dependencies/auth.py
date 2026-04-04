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
  mfa_verified: bool = False
  mfa_factor: str | None = None


def read_mfa_state(decoded_token: dict[str, object]) -> tuple[bool, str | None]:
  firebase_claims = decoded_token.get("firebase")
  second_factor: str | None = None
  # check if user used MFA
  if isinstance(firebase_claims, dict):
    raw_second_factor = firebase_claims.get("sign_in_second_factor")
    if isinstance(raw_second_factor, str) and raw_second_factor.strip():
      second_factor = raw_second_factor.strip().lower()

  # check if token says MFA was used
  amr = decoded_token.get("amr")

  has_mfa_amr = False  # default: MFA not found

  # check if amr is actually a list
  if isinstance(amr, list):
      # loop through each authentication method in the list
      for value in amr:
          if isinstance(value, str) and value.lower() == "mfa":
              has_mfa_amr = True  # MFA found
              break  
   # MFA is true if either second factor or AMR says MFA
  return second_factor is not None or has_mfa_amr, second_factor

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
  mfa_verified, mfa_factor = read_mfa_state(decoded_token)

  return CurrentUser(
    uid=uid,
    email=email,
    role=role,
    full_name=full_name,
    mfa_verified=mfa_verified,
    mfa_factor=mfa_factor,
  )

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