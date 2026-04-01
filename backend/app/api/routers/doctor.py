from fastapi import APIRouter, Depends

from app.dependencies.auth import CurrentUser, require_doctor_access
from app.schemas.doctor import (
    Appointment,
    AppointmentStatusUpdate,
    DoctorProfile,
    DoctorProfileUpdate,
    SessionSummaryUpdate,
)
from app.services.doctor_service import (
    get_doctor_appointment,
    get_doctor_profile,
    list_doctor_appointments,
    save_session_summary,
    update_appointment_status,
    update_doctor_profile,
)

router = APIRouter(prefix="/doctor", tags=["doctor"])


# Get the profile of the log in doctor
@router.get("/profile", response_model=DoctorProfile)
def get_my_profile(user: CurrentUser = Depends(require_doctor_access)) -> DoctorProfile:
    profile = get_doctor_profile(user.uid)
    if not profile.email:
        profile.email = user.email
    return profile


# Update doctor profile details
@router.patch("/profile", response_model=DoctorProfile)
def update_my_profile(
    payload: DoctorProfileUpdate,
    user: CurrentUser = Depends(require_doctor_access),
) -> DoctorProfile:
    return update_doctor_profile(user.uid, payload)


# Get all appointments for the log in doctor
@router.get("/appointments", response_model=list[Appointment])
def list_my_appointments(
    user: CurrentUser = Depends(require_doctor_access),
) -> list[Appointment]:
    return list_doctor_appointments(user.uid)


# Get details for one appointment owned by the current doctor.
@router.get("/appointments/{appointment_id}", response_model=Appointment)
def get_my_appointment(
    appointment_id: str,
    user: CurrentUser = Depends(require_doctor_access),
) -> Appointment:
    return get_doctor_appointment(user.uid, appointment_id)


# Updates the appointment status for an appointment owned by the current doctor.
@router.patch("/appointments/{appointment_id}/status", response_model=Appointment)
def update_appointment_status_route(
    appointment_id: str,
    payload: AppointmentStatusUpdate,
    user: CurrentUser = Depends(require_doctor_access),
) -> Appointment:
    return update_appointment_status(user.uid, appointment_id, payload.status)


# Saves notes and prescription metadata for an appointment session.
@router.patch("/appointments/{appointment_id}/session", response_model=Appointment)
def update_session_summary(
    appointment_id: str,
    payload: SessionSummaryUpdate,
    user: CurrentUser = Depends(require_doctor_access),
) -> Appointment:
    return save_session_summary(user.uid, appointment_id, payload)
