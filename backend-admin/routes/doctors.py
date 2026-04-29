from fastapi import APIRouter, Depends, HTTPException, Request
from firebase_admin import firestore, auth
from pydantic import BaseModel, EmailStr, Field
from typing import List
from auth import require_admin

router = APIRouter(tags=["Doctors"])
db = firestore.client()

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


@router.delete("/{doctor_id}")
def delete_doctor(doctor_id: str, user=Depends(require_admin)):
    doc_ref = db.collection("users").document(doctor_id)
    snapshot = doc_ref.get()

    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Doctor not found")

    data = snapshot.to_dict()
    if data.get("role") != "doctor":
        raise HTTPException(status_code=400, detail="User is not a doctor")

    uid = data.get("uid") or doctor_id

    doc_ref.delete()

    try:
        auth.delete_user(uid)
    except Exception:
        pass

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