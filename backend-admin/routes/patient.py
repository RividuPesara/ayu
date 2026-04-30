from fastapi import APIRouter, HTTPException, Depends
from firebase_admin import firestore
from pydantic import BaseModel
from typing import Optional
from auth import require_admin

router = APIRouter()
db = firestore.client()

class UpdatePatient(BaseModel):
    status: Optional[str] = None

@router.get("/")
def get_patients(user=Depends(require_admin)):
    docs = (
        db.collection("users")
        .where("role", "==", "patient")
        .stream()
    )

    patients = []
    for doc in docs:
        data = doc.to_dict()

        full_name = data.get("fullName")
        if not full_name:
            first_name = data.get("firstName", "")
            last_name = data.get("lastName", "")
            full_name = f"{first_name} {last_name}".strip()

        patients.append({
            "id": doc.id,
            "uid": data.get("uid", doc.id),
            "name": full_name or "Unknown Patient",
            "email": data.get("email", ""),
            "status": data.get("status", "Active"),
            "donationApproved": data.get("donationApproved", False),
            "companionName": data.get("companionName", ""),
            "companionEmail": data.get("companionEmail", ""),
            "cancerType": data.get("patientProfile", {}).get("cancerType", ""),
            "stage": data.get("patientProfile", {}).get("stage", ""),
            "avatar": data.get("avatar", ""),
        })

    return patients


@router.get("/{patient_id}")
def get_patient(patient_id: str, user=Depends(require_admin)):
    doc = db.collection("users").document(patient_id).get()

    if not doc.exists:
        raise HTTPException(status_code=404, detail="Patient not found")

    data = doc.to_dict()

    if data.get("role") != "patient":
        raise HTTPException(status_code=400, detail="User is not a patient")

    full_name = data.get("fullName")
    if not full_name:
        first_name = data.get("firstName", "")
        last_name = data.get("lastName", "")
        full_name = f"{first_name} {last_name}".strip()

    return {
        "id": doc.id,
        "uid": data.get("uid", doc.id),
        "firstName": data.get("firstName", ""),
        "lastName": data.get("lastName", ""),
        "name": full_name or "Unknown Patient",
        "email": data.get("email", ""),
        "status": data.get("status", "Active"),
        "donationApproved": data.get("donationApproved", False),
        "companionName": data.get("companionName", ""),
        "companionEmail": data.get("companionEmail", ""),
        "cancerType": data.get("patientProfile", {}).get("cancerType", ""),
        "stage": data.get("patientProfile", {}).get("stage", ""),
        "patientProfile": data.get("patientProfile", {}),
        "createdAt": data.get("createdAt"),
        "updatedAt": data.get("updatedAt"),
        "avatar": data.get("avatar", ""),
    }

@router.put("/{patient_id}")
def update_patient(patient_id: str, body: UpdatePatient, user=Depends(require_admin)):
    update_data = {}

    if body.status is not None:
        update_data["status"] = body.status

    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields to update")

    db.collection("users").document(patient_id).update(update_data)

    return {"message": "Updated successfully"}