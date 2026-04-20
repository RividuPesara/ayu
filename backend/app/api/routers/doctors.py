import asyncio
import functools

from fastapi import APIRouter, Depends, Query

from app.dependencies.auth import CurrentUser, require_patient_access
from app.schemas.doctors import DoctorSummary
from app.services.doctor_directory_service import get_doctor_by_uid, list_doctors

router = APIRouter(prefix="/doctors", tags=["doctors"])

# Runs separate thread to keep the API responsive
async def _run_sync(func, *args, **kwargs):
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, functools.partial(func, *args, **kwargs))

# Fetches a list of doctors with an adjustable limit
@router.get("", response_model=list[DoctorSummary])
async def get_doctor_list(
    limit: int = Query(default=200, ge=1, le=500),
    user: CurrentUser = Depends(require_patient_access),
) -> list[DoctorSummary]:
    return await _run_sync(list_doctors, limit)

# Gets full profile details for one specific doctor using their ID
@router.get("/{doctor_uid}", response_model=DoctorSummary)
async def get_doctor_detail(
    doctor_uid: str,
    user: CurrentUser = Depends(require_patient_access),
) -> DoctorSummary:
    return await _run_sync(get_doctor_by_uid, doctor_uid)
