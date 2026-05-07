from typing import Literal

from pydantic import BaseModel, Field

AccountStatus = Literal["active", "archived", "suspended"]


class PatientProfile(BaseModel):
    uid: str
    full_name: str = ""
    email: str | None = None
    phone: str | None = None
    avatar_url: str | None = None
    status: AccountStatus = "active"


class PatientProfileUpdate(BaseModel):
    first_name: str | None = Field(default=None, min_length=1, max_length=60)
    last_name: str | None = Field(default=None, min_length=1, max_length=60)
    phone: str | None = Field(default=None, pattern=r"^07\d{8}$")
    avatar_url: str | None = Field(default=None, min_length=4, max_length=500)


class AvatarUploadResponse(BaseModel):
    avatar_url: str


class AccountStatusResponse(BaseModel):
    uid: str
    status: AccountStatus


class AccountStatusUpdate(BaseModel):
    status: AccountStatus
