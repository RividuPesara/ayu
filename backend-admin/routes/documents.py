from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional
from firebase_admin import firestore

from firebase import db
from auth import require_admin

router = APIRouter()

class RejectBody(BaseModel):
    rejectionReason: str

class DonationBody(BaseModel):
    approvedForDonation: bool

def get_timestamp_now():
    return firestore.SERVER_TIMESTAMP

def format_firestore_datetime(value) -> str:
    if not value:
        return ""

    try:
        if hasattr(value, "strftime"):
            return value.strftime("%b %d, %Y")
    except Exception:
        pass

    return ""


def map_status(db_status: Optional[str]) -> str:
    status = (db_status or "pending").lower()

    if status == "approved":
        return "Approved"
    if status == "rejected":
        return "Rejected"
    return "Pending"


def is_approved_for_donation(data: dict) -> bool:
    if "approvedForDonation" in data:
        return bool(data.get("approvedForDonation"))
    return (data.get("status") or "").lower() == "approved"


def get_patient_name(patient_uid: str) -> str:
    if not patient_uid:
        return "Unknown Patient"

    try:
        user_doc = db.collection("users").document(patient_uid).get()

        if user_doc.exists:
            user_data = user_doc.to_dict() or {}

            if user_data.get("fullName"):
                return user_data["fullName"]

            first_name = user_data.get("firstName", "").strip()
            last_name = user_data.get("lastName", "").strip()
            full_name = f"{first_name} {last_name}".strip()

            if full_name:
                return full_name

    except Exception:
        pass

    return patient_uid


@router.get("")
def get_documents(user=Depends(require_admin)):
    try:
        docs = (
            db.collection("donationApplications")
            .order_by("createdAt", direction=firestore.Query.DESCENDING)
            .stream()
        )

        results = []

        for d in docs:
            data = d.to_dict() or {}
            medical_document = data.get("medicalDocument") or {}

            patient_uid = data.get("patientUid", "")
            db_status = (data.get("status") or "pending").lower()

            results.append({
                "id": d.id,
                "patient": get_patient_name(patient_uid),
                "document": medical_document.get("filename", "Untitled Document"),
                "documentUrl": medical_document.get("url", ""),
                "submitted": format_firestore_datetime(data.get("createdAt")),
                "status": map_status(db_status),
                "approvedForDonation": is_approved_for_donation(data),
                "rejectionComment": data.get("rejectionReason", ""),
            })

        return results

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch documents: {str(e)}"
        )


@router.patch("/{doc_id}/approve")
def approve_document(
    doc_id: str,
    user=Depends(require_admin),
):
    reviewer_uid = user.get("uid", "")

    try:
        ref = db.collection("donationApplications").document(doc_id)
        snap = ref.get()

        if not snap.exists:
            raise HTTPException(status_code=404, detail="Document not found")

        current = snap.to_dict() or {}
        patient_uid = current.get("patientUid")

        batch = db.batch()

        batch.update(ref, {
            "status": "approved",
            "rejectionReason": firestore.DELETE_FIELD,
            "reviewedAt": get_timestamp_now(),
            "reviewedByUid": reviewer_uid,
            "updatedAt": get_timestamp_now(),
            "approvedForDonation": True,
        })

        if patient_uid:
            user_ref = db.collection("users").document(patient_uid)
            batch.update(user_ref, {
                "donationApproved": True,
                "updatedAt": get_timestamp_now(),
            })

        batch.commit()

        return {"message": "Document approved successfully"}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Approve failed: {str(e)}"
        )


@router.patch("/{doc_id}/reject")
def reject_document(
    doc_id: str,
    body: RejectBody,
    user=Depends(require_admin),
):
    reviewer_uid = user.get("uid", "")

    if not body.rejectionReason.strip():
        raise HTTPException(
            status_code=400,
            detail="Rejection reason is required"
        )

    try:
        ref = db.collection("donationApplications").document(doc_id)
        snap = ref.get()

        if not snap.exists:
            raise HTTPException(status_code=404, detail="Document not found")

        current = snap.to_dict() or {}
        patient_uid = current.get("patientUid")

        batch = db.batch()

        batch.update(ref, {
            "status": "rejected",
            "rejectionReason": body.rejectionReason.strip(),
            "reviewedAt": get_timestamp_now(),
            "reviewedByUid": reviewer_uid,
            "updatedAt": get_timestamp_now(),
            "approvedForDonation": False,
        })

        if patient_uid:
            user_ref = db.collection("users").document(patient_uid)
            batch.update(user_ref, {
                "donationApproved": False,
                "updatedAt": get_timestamp_now(),
            })

        batch.commit()

        return {"message": "Document rejected successfully"}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Reject failed: {str(e)}"
        )


@router.patch("/{doc_id}/donation")
def update_donation_approval(
    doc_id: str,
    body: DonationBody,
    user=Depends(require_admin),
):
    reviewer_uid = user.get("uid", "")

    try:
        ref = db.collection("donationApplications").document(doc_id)
        snap = ref.get()

        if not snap.exists:
            raise HTTPException(status_code=404, detail="Document not found")

        current = snap.to_dict() or {}
        current_status = (current.get("status") or "").lower()
        patient_uid = current.get("patientUid")

        if current_status != "approved":
            raise HTTPException(
                status_code=400,
                detail="Donation approval can only be changed for approved documents",
            )

        batch = db.batch()

        batch.update(ref, {
            "approvedForDonation": body.approvedForDonation,
            "reviewedByUid": reviewer_uid,
            "updatedAt": get_timestamp_now(),
        })

        if patient_uid:
            user_ref = db.collection("users").document(patient_uid)
            batch.update(user_ref, {
                "donationApproved": body.approvedForDonation,
                "updatedAt": get_timestamp_now(),
            })

        batch.commit()

        return {"message": "Donation approval updated successfully"}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Donation approval update failed: {str(e)}"
        )