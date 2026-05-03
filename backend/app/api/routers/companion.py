import asyncio
import functools

from fastapi import APIRouter, Depends, status

from app.dependencies.auth import CurrentUser, require_patient_access, require_patient_or_companion_access
from app.schemas.companion import (
    CompanionInviteRequest,
    CompanionInviteResponse,
    CompanionStatusResponse,
)
from app.services.companion_service import get_companion_status, send_companion_invite

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
