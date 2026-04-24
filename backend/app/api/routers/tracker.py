import asyncio
import functools

from fastapi import APIRouter, Depends, Query, status

from app.dependencies.auth import CurrentUser, require_patient_access
from app.schemas.tracker import (
    DayScheduleResponse,
    MarkTakenRequest,
    MedicationCreateRequest,
    MedicationResponse,
)
from app.services.tracker_service import (
    create_medication,
    delete_medication,
    get_day_schedule,
    list_medications,
    mark_taken,
)

router = APIRouter(prefix="/tracker", tags=["tracker"])


async def _run_sync(func, *args):
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, functools.partial(func, *args))


@router.post("/medications", response_model=MedicationResponse, status_code=status.HTTP_201_CREATED)
async def add_medication(payload: MedicationCreateRequest,user: CurrentUser = Depends(require_patient_access),) -> MedicationResponse:
    # Register a new medication
    return await _run_sync(
        create_medication,
        user.uid,
        payload.name,
        payload.type,
        payload.times,
        payload.repeat_until,
    )

# Retrieve the list of all active medications for the authenticated patient
@router.get("/medications", response_model=list[MedicationResponse])
async def get_medications(
    user: CurrentUser = Depends(require_patient_access),) -> list[MedicationResponse]:
    return await _run_sync(list_medications, user.uid)

# Permanently remove a medication
@router.delete("/medications/{medication_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_medication(
    medication_id: str,
    user: CurrentUser = Depends(require_patient_access),) -> None:
    await _run_sync(delete_medication, user.uid, medication_id)


@router.post("/logs/take", status_code=status.HTTP_200_OK)
async def take_medication(
    # Record a 'taken' event for a specific medication
    payload: MarkTakenRequest,
    user: CurrentUser = Depends(require_patient_access),) -> dict:
    return await _run_sync(
        mark_taken,
        user.uid,
        payload.medication_id,
        payload.date_key,
        payload.scheduled_time,
    )


@router.get("/schedule", response_model=DayScheduleResponse)
async def get_schedule(
    # Get the combined list of scheduled and completed medications for a specific date
    date: str = Query(description="Target date in YYYY-MM-DD format"),
    user: CurrentUser = Depends(require_patient_access),) -> DayScheduleResponse:
    result = await _run_sync(get_day_schedule, user.uid, date)
    return DayScheduleResponse.model_validate(result)
