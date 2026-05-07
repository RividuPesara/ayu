from fastapi import APIRouter, Depends, File, UploadFile

from app.dependencies.auth import get_current_user, CurrentUser
from app.schemas.donation import DonationSubmitResponse, DonationStatusResponse
from app.services.donation_service import submit_donation_application, get_donation_status

router = APIRouter(prefix="/donation", tags=["Donation"])


@router.post("/submit", response_model=DonationSubmitResponse)
async def submit_donation(file: UploadFile = File(...),user: CurrentUser = Depends(get_current_user),
):
    return await submit_donation_application(uid=user.uid, file=file)


@router.get("/status", response_model=DonationStatusResponse)
def donation_status(user: CurrentUser = Depends(get_current_user)):
    return get_donation_status(uid=user.uid)
