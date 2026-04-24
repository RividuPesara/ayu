from datetime import datetime

from pydantic import BaseModel, Field


class MedicationCreateRequest(BaseModel):
    # New medication submitted by the patient
    name: str = Field(min_length=1, max_length=100)
    type: str = Field(min_length=1, max_length=50)
    times: list[str] = Field(min_length=1, max_length=10)
    repeat_until: str = Field(min_length=10, max_length=10)


class MedicationResponse(BaseModel):
    # Medication document 
    medication_id: str
    user_id: str
    name: str
    type: str
    times: list[str]
    repeat_until: str
    start_date: str
    created_at: datetime | None = None


class MarkTakenRequest(BaseModel):
    # Patient submitted confirmation that a scheduled dose was taken
    medication_id: str
    date_key: str = Field(min_length=10, max_length=10)
    scheduled_time: str = Field(min_length=5, max_length=5)


class ScheduleItemResponse(BaseModel):
    # One time slot for a medication on a specific day
    medication_id: str
    name: str
    type: str
    scheduled_time: str
    status: str
    log_id: str | None = None


class DayScheduleResponse(BaseModel):
    date_key: str
    items: list[ScheduleItemResponse] = Field(default_factory=list)
