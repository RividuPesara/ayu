from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.doctor import AppointmentStatus

# Represents a single time block and if its taken
class AppointmentSlotTime(BaseModel):
    time: str
    available: bool = True

# Groups time slots under a specific day
class AppointmentSlotDate(BaseModel):
    date_key: str
    day: str
    weekday: str
    times: list[AppointmentSlotTime] = Field(default_factory=list)

# The full list of available days and times sent to the frontend
class AppointmentSlotsResponse(BaseModel):
    timezone: str
    dates: list[AppointmentSlotDate] = Field(default_factory=list)

# Used to ask specific doctor's availability
class AppointmentSlotsRequest(BaseModel):
    doctor_uid: str = Field(min_length=1)

# The data sent by the patient when they click the 'Book' button
class BookAppointmentRequest(BaseModel):
    date_key: str = Field(pattern=r"^\d{4}-\d{2}-\d{2}$") # YYYY-MM-DD
    time: str = Field(pattern=r"^\d{2}:\d{2}$") # HH:MM
    doctor_uid: str = Field(min_length=1)
    doctor_name: str = Field(min_length=1, max_length=160)
    doctor_specialty: str | None = Field(default=None, max_length=160)
    type: str = Field(default="consultation", max_length=80)
    intake_note: str | None = Field(default=None, max_length=2000)

# The confirmation sent back to the app after a successful booking
class BookAppointmentResponse(BaseModel):
    appointment_id: str
    date_key: str
    time: str
    zoom_meeting_id: str | None = None
    zoom_passcode: str | None = None
    zoom_join_url: str | None = None

# The detailed appointment object shown in the patient's My Bookings list
class PatientAppointment(BaseModel):
    id: str
    doctor_name: str
    doctor_specialty: str | None = None
    doctor_avatar_url: str | None = None
    date_key: str | None = None
    time: str = ""
    type: str = "consultation"
    status: AppointmentStatus = "upcoming"
    zoom_meeting_id: str | None = None
    zoom_passcode: str | None = None
    zoom_join_url: str | None = None
    prescription_url: str | None = None
    prescription_filename: str | None = None
    documentation_url: str | None = None
    documentation_filename: str | None = None
