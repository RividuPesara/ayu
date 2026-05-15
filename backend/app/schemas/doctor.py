from typing import Literal

from pydantic import BaseModel, Field

AppointmentStatus = Literal["done", "upcoming", "overdue"]
AppointmentFileCategory = Literal["prescription", "documentation"]


class DoctorProfile(BaseModel):
    # doctor details
    uid: str    #not used
    full_name: str = ""
    specialty: str | None = None
    phone: str | None = None
    avatar_url: str | None = None
    email: str | None = None   #not used


class DoctorProfileUpdate(BaseModel):
    # Fields allowed when updating a doctor profile
    full_name: str | None = Field(default=None, min_length=2, max_length=120)
    specialty: str | None = Field(default=None, min_length=2, max_length=120)
    phone: str | None = Field(default=None, pattern=r"^07\d{8}$")
    avatar_url: str | None = Field(default=None, min_length=4, max_length=500)


class AvatarUploadResponse(BaseModel):
    avatar_url: str


class AppointmentFileUploadResponse(BaseModel):
    url: str
    filename: str
    category: AppointmentFileCategory


class Appointment(BaseModel):
    # Appointment data shown in the doctor dashboard
    id: str
    doctor_uid: str | None = None  
    patient_uid: str | None = None
    name: str = ""
    time: str = ""
    type: str = "consultation"
    status: AppointmentStatus = "upcoming"
    date: str | None = None
    zoom_meeting_id: str | None = None
    zoom_passcode: str | None = None
    zoom_start_url: str | None = None
    clinical_notes: str | None = None
    intake_note: str | None = None
    prescription_url: str | None = None
    prescription_filename: str | None = None
    documentation_url: str | None = None
    documentation_filename: str | None = None


class AppointmentStatusUpdate(BaseModel):
     # update the status of an appointment
    status: AppointmentStatus


class SessionSummaryUpdate(BaseModel):
   # Save consultation notes and prescription details
    clinical_notes: str | None = Field(default=None, max_length=10000)
    prescription_url: str | None = Field(default=None, max_length=500)
    prescription_filename: str | None = Field(default=None, max_length=255)
    documentation_url: str | None = Field(default=None, max_length=500)
    documentation_filename: str | None = Field(default=None, max_length=255)
