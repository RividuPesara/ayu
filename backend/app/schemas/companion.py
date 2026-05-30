from pydantic import BaseModel


class CompanionInviteRequest(BaseModel):
    email: str


class CompanionInfo(BaseModel):
    uid: str
    email: str
    name: str | None = None
    avatar: str | None = None
    status: str  # "pending" or "active"


class CompanionInviteResponse(BaseModel):
    status: str
    invite_id: str


class CompanionStatusResponse(BaseModel):
    has_companion: bool
    companion: CompanionInfo | None = None

class CompanionPrivacyRequest(BaseModel):
    mood_journal: bool = True
    todo_list: bool = False
    tracking: bool = True
    doctor_appointments: bool = True


class CompanionPrivacyResponse(BaseModel):
    mood_journal: bool
    todo_list: bool
    tracking: bool
    doctor_appointments: bool


class PatientMoodStatusResponse(BaseModel):
    current_status: str
    emotion_message: str
    has_crisis: bool
    recent_entry_flagged: bool  # any entry in last 7 days had aiMood=="Suicidal" AND safetyFlag=="crisis"
    last_active_date_key: str
