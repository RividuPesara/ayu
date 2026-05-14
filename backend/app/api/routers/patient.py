import asyncio
import functools

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from app.dependencies.auth import CurrentUser, require_patient_access, require_patient_or_companion_access
from app.schemas.patient import (
    AccountStatusResponse,
    AccountStatusUpdate,
    AvatarUploadResponse,
    PatientProfile,
    PatientProfileUpdate,
)
from app.services.patient_service import (
    get_account_status_for_uid,
    get_patient_profile,
    set_account_status,
    update_patient_profile,
    upload_patient_avatar,
)
from app.services.user_service import invalidate_status_cache

router = APIRouter(prefix="/patient", tags=["patient"])


async def _run_sync(func, *args):
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, functools.partial(func, *args))

# Fetches the user's personal info
@router.get("/profile", response_model=PatientProfile)
async def get_my_profile(user: CurrentUser = Depends(require_patient_or_companion_access),
) -> PatientProfile:
    profile = await _run_sync(get_patient_profile, user.uid)
    if not profile.email:
        profile.email = user.email
    return profile

# Saves changes to the user's personal info
@router.patch("/profile", response_model=PatientProfile)
async def update_my_profile(payload: PatientProfileUpdate, user: CurrentUser = Depends(require_patient_or_companion_access),
) -> PatientProfile:
    return await _run_sync(update_patient_profile, user.uid, payload)


@router.post("/profile/avatar", response_model=AvatarUploadResponse)
async def upload_my_avatar(avatar: UploadFile = File(...), user: CurrentUser = Depends(require_patient_or_companion_access),
) -> AvatarUploadResponse:
    file_content = await avatar.read()
    if not file_content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Avatar file is empty.",
        )

    avatar_url = await _run_sync(upload_patient_avatar, user.uid, file_content, avatar.content_type)
    return AvatarUploadResponse(avatar_url=avatar_url)


@router.get("/status", response_model=AccountStatusResponse)
async def get_my_status(user: CurrentUser = Depends(require_patient_access),
) -> AccountStatusResponse:
    return await _run_sync(get_account_status_for_uid, user.uid)


@router.patch("/status", response_model=AccountStatusResponse)
async def update_my_status(payload: AccountStatusUpdate,user: CurrentUser = Depends(require_patient_access),
) -> AccountStatusResponse:
    result = await _run_sync(set_account_status, user.uid, payload.status)
    invalidate_status_cache(user.uid)
    return result
