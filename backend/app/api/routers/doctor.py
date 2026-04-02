from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from app.dependencies.auth import CurrentUser, require_doctor_access
from app.schemas.doctor import (
    Appointment,
    AppointmentFileCategory,
    AppointmentFileUploadResponse,
    AvatarUploadResponse,
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
    upload_appointment_file_to_cloudinary,
    update_doctor_avatar,
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

# Upload or update the doctor's avatar image
@router.post("/profile/avatar", response_model=AvatarUploadResponse)
async def upload_my_avatar(
    avatar: UploadFile = File(...),
    user: CurrentUser = Depends(require_doctor_access),
) -> AvatarUploadResponse:
    file_content = await avatar.read()
    if not file_content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Avatar file is empty.",
        )

    avatar_url = update_doctor_avatar(user.uid, file_content, avatar.content_type)
    return AvatarUploadResponse(avatar_url=avatar_url)


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

# Upload a file for a appointment
@router.post(
    "/appointments/{appointment_id}/files",
    response_model=AppointmentFileUploadResponse,
)
async def upload_appointment_file(
    appointment_id: str,
    category: AppointmentFileCategory,
    file: UploadFile = File(...),
    user: CurrentUser = Depends(require_doctor_access),
) -> AppointmentFileUploadResponse:
    file_content = await file.read()
    if not file_content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty.",
        )

    uploaded_url, uploaded_filename = upload_appointment_file_to_cloudinary(
        uid=user.uid,
        appointment_id=appointment_id,
        category=category,
        content=file_content,
        content_type=file.content_type,
        filename=file.filename,
    )

    return AppointmentFileUploadResponse(
        url=uploaded_url,
        filename=uploaded_filename,
        category=category,
    )
