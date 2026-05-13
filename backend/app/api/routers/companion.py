import asyncio
import functools

from fastapi import APIRouter, Depends, status

from app.dependencies.auth import CurrentUser, require_patient_access, require_patient_or_companion_access
from app.schemas.companion import (
    CompanionInviteRequest,
    CompanionInviteResponse,
    CompanionPrivacyRequest,
    CompanionPrivacyResponse,
    CompanionStatusResponse,
)
from app.services.companion_service import (
    get_companion_privacy,
    get_companion_status,
    save_companion_privacy,
    send_companion_invite,
    unlink_companion,
)

router = APIRouter(prefix="/companion", tags=["companion"])


async def _run_sync(func, *args):
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, functools.partial(func, *args))


@router.post("/invite", response_model=CompanionInviteResponse, status_code=status.HTTP_200_OK)
async def invite_companion(payload: CompanionInviteRequest,
    user: CurrentUser = Depends(require_patient_access),) -> CompanionInviteResponse:
    # Only patients can send companion invites
    result = await _run_sync(
        send_companion_invite,
        user.uid,
        user.full_name,
        user.email,
        payload.email,
    )
    return CompanionInviteResponse.model_validate(result)


@router.get("/status", response_model=CompanionStatusResponse, status_code=status.HTTP_200_OK)
async def companion_status(
    user: CurrentUser = Depends(require_patient_or_companion_access),) -> CompanionStatusResponse:
    # Both patient and companion can check status
    result = await _run_sync(get_companion_status, user.uid, user.role)
    return CompanionStatusResponse.model_validate(result)


@router.post("/privacy", response_model=CompanionPrivacyResponse, status_code=status.HTTP_200_OK)
async def update_privacy(payload: CompanionPrivacyRequest,
user: CurrentUser = Depends(require_patient_access),
) -> CompanionPrivacyResponse:
    # Only the patient controls what their companion can see
    result = await _run_sync(
        save_companion_privacy,
        user.uid,
        payload.mood_journal,
        payload.todo_list,
        payload.tracking,
        payload.doctor_appointments,
    )
    return CompanionPrivacyResponse.model_validate(result)


@router.get("/privacy", response_model=CompanionPrivacyResponse, status_code=status.HTTP_200_OK)
async def get_privacy(user: CurrentUser = Depends(require_patient_or_companion_access),
) -> CompanionPrivacyResponse:
    # Patient reads own settings . companion reads their patient's settings using service
    result = await _run_sync(get_companion_privacy, user.uid, user.role)
    return CompanionPrivacyResponse.model_validate(result)

@router.delete("", status_code=status.HTTP_200_OK)
async def delete_companion(
    user: CurrentUser = Depends(require_patient_access),
) -> dict:
    # Patient unlinks their companion
    result = await _run_sync(unlink_companion, user.uid)
    return result
