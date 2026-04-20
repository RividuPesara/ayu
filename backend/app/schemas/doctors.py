from pydantic import BaseModel


class DoctorSummary(BaseModel):
    uid: str
    full_name: str = ""
    specialty: str | None = None
    phone: str | None = None
    avatar_url: str | None = None
    email: str | None = None
