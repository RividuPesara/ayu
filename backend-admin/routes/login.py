from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from firebase_admin import firestore, auth as firebase_auth
import re

router = APIRouter()
db = firestore.client()
auth_client = firebase_auth

class AdminVerifyRequest(BaseModel):
    uid: str

class SendOtpRequest(BaseModel):
    email: str
    password: str

class VerifyOtpRequest(BaseModel):
    uid: str
    verification_id: str
    otp_code: str

class OtpResponse(BaseModel):
    message: str
    verification_id: str
    phone_masked: str

@router.post("/verify-admin")
def verify_admin(data: AdminVerifyRequest):
    user_doc = db.collection("users").document(data.uid).get()

    if not user_doc.exists:
        raise HTTPException(
            status_code=404,
            detail="User not found in users collection"
        )

    user_data = user_doc.to_dict()

    role = user_data.get("role", "").lower()

    if role != "admin":
        raise HTTPException(
            status_code=403,
            detail="Access denied: you are not an admin"
        )

    return {
        "message": "Admin verified successfully",
        "uid": data.uid,
        "role": user_data.get("role")
    }

def mask_phone(phone: str) -> str:
    digits = re.sub(r'\D', '', phone)
    if len(digits) < 4:
        return "your phone"
    return f"*******{digits[-3:]}"

@router.post("/send-otp")
def send_otp(data: SendOtpRequest):
    try:
        user = auth_client.get_user_by_email(data.email)
        uid = user.uid

        if not user.email_verified:
            raise HTTPException(
                status_code=400,
                detail="Please verify your email first. We sent a verification link to your email."
            )

        user_doc = db.collection("users").document(uid).get()

        if not user_doc.exists:
            raise HTTPException(
                status_code=404,
                detail="User not found in users collection"
            )

        user_data = user_doc.to_dict()
        role = user_data.get("role", "").lower()

        if role != "admin":
            raise HTTPException(
                status_code=403,
                detail="Access denied: you are not an admin"
            )

        phone = user_data.get("phone", "").strip()
        if not phone:
            raise HTTPException(
                status_code=400,
                detail="No phone number found in your profile. Please contact admin to set your phone number."
            )

        phone_masked = mask_phone(phone)

        return OtpResponse(
            message="OTP will be sent to your registered phone number. Complete the verification on your client device.",
            verification_id=f"admin-{uid}-{phone}",
            phone_masked=phone_masked
        )

    except firebase_auth.UserNotFoundError:
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password"
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Authentication failed: {str(e)}"
        )

@router.post("/verify-otp")
def verify_otp(data: VerifyOtpRequest):
    try:
        user_doc = db.collection("users").document(data.uid).get()

        if not user_doc.exists:
            raise HTTPException(
                status_code=404,
                detail="User not found in users collection"
            )

        user_data = user_doc.to_dict()
        role = user_data.get("role", "").lower()

        if role != "admin":
            raise HTTPException(
                status_code=403,
                detail="Access denied: you are not an admin"
            )

        otp_code = data.otp_code.strip()
        if not re.match(r'^\d{6}$', otp_code):
            raise HTTPException(
                status_code=400,
                detail="Please enter a valid 6-digit OTP code."
            )

        return {
            "message": "OTP verified successfully",
            "uid": data.uid,
            "role": user_data.get("role")
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"OTP verification failed: {str(e)}"
        )