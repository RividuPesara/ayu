import asyncio
import functools
import logging

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.dependencies.auth import CurrentUser, require_patient_or_companion_access
from app.services.companion_service import cleanup_expired_invites
from app.services.appointment_service import send_appointment_reminders

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/notifications", tags=["notifications"])

USERS_COLLECTION = "users"


async def _run_sync(func, *args):
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, functools.partial(func, *args))


# device registration
class DeviceRegisterRequest(BaseModel):
    device_id: str
    fcm_token: str
    platform: str


@router.post("/devices", status_code=status.HTTP_200_OK)
async def register_device(
    payload: DeviceRegisterRequest,
    user: CurrentUser = Depends(require_patient_or_companion_access),
) -> dict:
    # upsert the device doc with the latest token and mark enabled
    def _upsert():
        from firebase_admin import firestore as fs
        db = get_firestore_client()
        db.collection(USERS_COLLECTION).document(user.uid).collection("devices").document(
            payload.device_id
        ).set(
            {
                "fcmToken": payload.fcm_token,
                "platform": payload.platform,
                "lastSeenAt": fs.SERVER_TIMESTAMP,
                "enabled": True,
            },
            merge=True,
        )

    await _run_sync(_upsert)
    return {"status": "registered"}


@router.delete("/devices/{device_id}", status_code=status.HTTP_200_OK)
async def unregister_device(
    device_id: str,
    user: CurrentUser = Depends(require_patient_or_companion_access),
) -> dict:
    # delete the device doc on logout
    def _delete():
        db = get_firestore_client()
        db.collection(USERS_COLLECTION).document(user.uid).collection("devices").document(
            device_id
        ).delete()

    await _run_sync(_delete)
    return {"status": "unregistered"}

def _verify_job_secret(x_job_secret: str | None = Header(default=None)) -> None:
    settings = get_settings()
    if not settings.job_runner_secret:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Job runner not configured",
        )
    if x_job_secret != settings.job_runner_secret:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid job secret",
        )


@router.post("/internal/run-jobs", status_code=status.HTTP_200_OK, include_in_schema=False)
async def run_jobs(_: None = Depends(_verify_job_secret)) -> dict:
    # runs background maintenance jobs, called by external cron every 5 min
    invites_result = await _run_sync(cleanup_expired_invites)
    reminders_result = await _run_sync(send_appointment_reminders)
    return {
        "invites_cleaned": invites_result.get("cleaned_up", 0),
        "appointment_reminders_sent": reminders_result.get("sent", 0),
    }
