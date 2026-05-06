import asyncio
import functools

from fastapi import APIRouter, Depends, status

from app.dependencies.auth import CurrentUser, require_patient_access
from app.schemas.appointments import (
    AppointmentSlotsRequest,
    AppointmentSlotsResponse,
    BookAppointmentRequest,
    BookAppointmentResponse,
    PatientAppointment,
)
from app.services.appointment_service import (
    book_appointment,
    list_available_slots,
    list_patient_appointments,
)

# Grouping all appointment related routes under /appointments
router = APIRouter(prefix="/appointments", tags=["appointments"])

# sync tasks without freezing the app
async def _run_sync(func, *args, **kwargs):
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, functools.partial(func, *args, **kwargs))

# Shows what times a specific doctor is free
@router.get("/slots", response_model=AppointmentSlotsResponse)
async def get_available_slots(
    doctor_uid: str,
    user: CurrentUser = Depends(require_patient_access),
) -> AppointmentSlotsResponse:
    payload = AppointmentSlotsRequest(doctor_uid=doctor_uid)
    return await _run_sync(list_available_slots, payload)

# Handles the actual booking and creation of the appointment record
@router.post("/book", response_model=BookAppointmentResponse, status_code=status.HTTP_201_CREATED)
async def book_new_appointment(payload: BookAppointmentRequest,user: CurrentUser = Depends(require_patient_access),) -> BookAppointmentResponse:
    return await _run_sync(
        book_appointment,
        uid=user.uid,
        user_email=user.email,
        user_name=user.full_name,
        payload=payload,
    )

# Retrieves a list of all appointments for the logged in patient
@router.get("/my", response_model=list[PatientAppointment])
async def get_my_appointments(
    user: CurrentUser = Depends(require_patient_access),
) -> list[PatientAppointment]:
    return await _run_sync(list_patient_appointments, user.uid)
