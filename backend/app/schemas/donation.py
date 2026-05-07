from pydantic import BaseModel
from typing import Optional


class DonationSubmitResponse(BaseModel):
    applicationId: str
    status: str
    createdAt: str


class DonationStatusResponse(BaseModel):
    applicationId: str
    status: str
    rejectionReason: Optional[str] = None
    createdAt: str
    updatedAt: str
