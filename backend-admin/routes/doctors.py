from fastapi import APIRouter, Depends, HTTPException
from firebase_admin import firestore, auth
from pydantic import BaseModel, EmailStr, Field
from typing import List
from auth import require_admin

import os
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail
from dotenv import load_dotenv
load_dotenv()

router = APIRouter(tags=["Doctors"])
db = firestore.client()

SENDGRID_API_KEY = os.getenv("SENDGRID_API_KEY")
SENDGRID_FROM_EMAIL = os.getenv("SENDGRID_FROM_EMAIL")
APP_BASE_URL = os.getenv("APP_BASE_URL")

class DoctorCreate(BaseModel):
    fullName: str
    email: EmailStr
    password: str = Field(min_length=8)
    phone: str
    address: str
    slmcNumber: str
    specialty: str
    qualifications: List[str]

class StatusUpdate(BaseModel):
    status: str

class DoctorUpdate(BaseModel):
    fullName: str
    email: EmailStr
    phone: str
    address: str
    slmcNumber: str
    specialty: str
    qualifications: List[str]

VALID_STATUS = ["Active", "Archived", "Suspended"]

@router.get("/")
def get_doctors(user=Depends(require_admin)):
    docs = db.collection("users").where("role", "==", "doctor").stream()

    doctors = []
    for doc in docs:
        data = doc.to_dict()
        profile = data.get("doctorProfile", {}) or {}

        doctors.append({
            "id": doc.id,
            "fullName": data.get("fullName", ""),
            "email": data.get("email", ""),
            "phone": data.get("phone", ""),
            "address": profile.get("address", ""),
            "slmcNumber": profile.get("slmcNumber", ""),
            "specialty": profile.get("specialty", ""),
            "qualifications": profile.get("qualifications", []),
            "status": data.get("status", "Active"),
            "avatar": data.get("avatar", ""),
            "uid": data.get("uid", ""),
        })

    return doctors

def send_doctor_welcome_email(to_email: str, full_name: str, reset_link: str):
    if not SENDGRID_API_KEY or not SENDGRID_FROM_EMAIL:
        raise RuntimeError("SendGrid environment variables are not configured")

    html_content = f"""
    <html>
    <body style="margin:0; padding:0; background:#f4f6f8; font-family:Arial, sans-serif;">

        <div style="max-width:600px; margin:40px auto; background:white; border-radius:12px; overflow:hidden; box-shadow:0 4px 20px rgba(0,0,0,0.08);">

        <!-- LOGO SECTION -->
        <div style="text-align:center; padding:24px;">
            <img src="https://res.cloudinary.com/duysmfmo4/image/upload/v1775669462/logoIm_cpiwwj.png" 
                alt="Ayu Logo" 
                style="height:120px; width: 120px;" />
        </div>

        <!-- HEADER -->
        <div style=" padding:14px; color:black; text-align:center;">
            <h2 style="margin:0;">Welcome to AYU</h2>
        </div>

        <!-- BODY -->
        <div style="padding:24px;">
            <p>Hello Dr. <strong>{full_name}</strong>,</p>

            <p>Your doctor account has been created successfully.</p>

            <p>You can sign in using your email address:</p>

            <p style="font-weight: bold;">{to_email}</p>

            <p>To set your password, click below:</p>

            <div style="text-align:center; margin:24px 0;">
            <a href="{reset_link}" 
                style="background:#4f46e5; color:white; padding:12px 24px; text-decoration:none; border-radius:8px; font-weight:bold;">
                Set Your Password
            </a>
            </div>

            <p>If the button doesn’t work, use this link:</p>
            <p style="word-break:break-all;">
            <a href="{reset_link}">{reset_link}</a>
            </p>

            <p style="margin-top:24px;">Thanks for joining with us!</p>
        </div>

        <!-- FOOTER -->
        <div style="background:#f9fafb; padding:16px; text-align:center; font-size:12px; color:#666;">
            This is a system-generated email from AYU. Please do not reply to this email.
        </div>

        </div>

    </body>
    </html>
    """

    message = Mail(
        from_email=SENDGRID_FROM_EMAIL,
        to_emails=to_email,
        subject="Your AYU doctor account is ready",
        html_content=html_content,
    )

    try:
        sg = SendGridAPIClient(SENDGRID_API_KEY)
        response = sg.send(message)

        if response.status_code not in [200, 202]:
            raise Exception(f"Email failed with status {response.status_code}")

        print("Email sent successfully")

    except Exception as e:
        print("Email sending failed:", str(e))
        raise Exception(f"Email sending failed: {str(e)}")

@router.post("/")
def create_doctor(doctor: DoctorCreate, user=Depends(require_admin)):
    try:
        user_record = auth.create_user(
            email=doctor.email,
            password=doctor.password,
            display_name=doctor.fullName,
        )
    except auth.EmailAlreadyExistsError:
        raise HTTPException(status_code=400, detail="Email already exists in Firebase Auth")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to create auth user: {str(e)}")

    try:
        reset_link = auth.generate_password_reset_link(
            doctor.email,
            action_code_settings=auth.ActionCodeSettings(
                url=f"{APP_BASE_URL}/login",
                handle_code_in_app=False,
            ),
        )

        firestore_data = {
            "uid": user_record.uid,
            "fullName": doctor.fullName,
            "email": doctor.email,
            "phone": doctor.phone,
            "role": "doctor",
            "status": "Active",
            "avatar": "",
            "doctorProfile": {
                "specialty": doctor.specialty,
                "qualifications": doctor.qualifications,
                "slmcNumber": doctor.slmcNumber,
                "address": doctor.address,
            },
        }

        db.collection("users").document(user_record.uid).set(firestore_data)

        send_doctor_welcome_email(
            to_email=doctor.email,
            full_name=doctor.fullName,
            reset_link=reset_link,
        )

        return {
            "id": user_record.uid,
            "uid": user_record.uid,
            "fullName": doctor.fullName,
            "email": doctor.email,
            "phone": doctor.phone,
            "address": doctor.address,
            "slmcNumber": doctor.slmcNumber,
            "specialty": doctor.specialty,
            "qualifications": doctor.qualifications,
            "status": "Active",
            "avatar": "",
        }

    except Exception as e:
        try:
            auth.delete_user(user_record.uid)
        except Exception:
            pass
        raise HTTPException(status_code=500, detail=f"Failed to finish doctor creation: {str(e)}")


@router.patch("/{doctor_id}/status")
def update_status(doctor_id: str, payload: StatusUpdate, user=Depends(require_admin)):
    if payload.status not in VALID_STATUS:
        raise HTTPException(status_code=400, detail="Invalid status")

    doc_ref = db.collection("users").document(doctor_id)
    snapshot = doc_ref.get()

    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Doctor not found")

    data = snapshot.to_dict()
    if data.get("role") != "doctor":
        raise HTTPException(status_code=400, detail="User is not a doctor")

    doc_ref.update({"status": payload.status})
    return {"success": True}

@router.patch("/{doctor_id}")
def update_doctor(doctor_id: str, payload: DoctorUpdate, user=Depends(require_admin)):
    doc_ref = db.collection("users").document(doctor_id)
    snapshot = doc_ref.get()

    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Doctor not found")

    existing_data = snapshot.to_dict()
    if existing_data.get("role") != "doctor":
        raise HTTPException(status_code=400, detail="User is not a doctor")

    # If email changed, also update Firebase Auth
    uid = existing_data.get("uid") or doctor_id
    try:
        auth.update_user(
            uid,
            email=payload.email,
            display_name=payload.fullName,
        )
    except auth.EmailAlreadyExistsError:
        raise HTTPException(status_code=400, detail="Email already exists in Firebase Auth")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to update auth user: {str(e)}")

    updated_firestore_data = {
        "fullName": payload.fullName,
        "email": payload.email,
        "phone": payload.phone,
        "doctorProfile": {
            "specialty": payload.specialty,
            "qualifications": payload.qualifications,
            "slmcNumber": payload.slmcNumber,
            "address": payload.address,
        },
    }

    doc_ref.update(updated_firestore_data)

    latest = doc_ref.get().to_dict()
    profile = latest.get("doctorProfile", {}) or {}

    return {
        "id": doctor_id,
        "uid": latest.get("uid", ""),
        "fullName": latest.get("fullName", ""),
        "email": latest.get("email", ""),
        "phone": latest.get("phone", ""),
        "address": profile.get("address", ""),
        "slmcNumber": profile.get("slmcNumber", ""),
        "specialty": profile.get("specialty", ""),
        "qualifications": profile.get("qualifications", []),
        "status": latest.get("status", "Active"),
        "avatar": latest.get("avatar", ""),
    }