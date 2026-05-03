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
