from fastapi import APIRouter, Depends

from app.dependencies.auth import CurrentUser, get_current_user
from app.schemas.auth import AuthStatusResponse

router = APIRouter(prefix="/auth", tags=["auth"])

# Returns details of the currently log in user
@router.get("/me", response_model=AuthStatusResponse)
async def get_auth_status(user: CurrentUser = Depends(get_current_user)) -> AuthStatusResponse:
  return AuthStatusResponse(
    uid=user.uid,
    role=user.role,
    email=user.email,
    full_name=user.full_name,
    mfa_verified=user.mfa_verified,
    mfa_factor=user.mfa_factor,
  )
