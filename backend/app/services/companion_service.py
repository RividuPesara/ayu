import logging
import secrets
import string
from datetime import datetime, timedelta, timezone

import sendgrid
from sendgrid.helpers.mail import Mail

from fastapi import HTTPException, status
from firebase_admin import auth as firebase_auth
from firebase_admin import firestore

from app.core.config import get_settings
from app.core.firebase import get_firestore_client

logger = logging.getLogger(__name__)

USERS_COLLECTION = "users"
COMPANION_INVITES_COLLECTION = "companionInvites"
INVITE_EXPIRY_DAYS = 7


def _random_password(length: int = 24) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


def _send_invite_email(to_email: str, from_name: str, reset_link: str | None) -> None:
    settings = get_settings()
    if not settings.sendgrid_api_key:
        logger.warning("SendGrid API key not configured — skipping invite email")
        return

    # new users get a password reset link, existing users get a plain nudge
    if reset_link:
        html_content = f"""
        <p>Hi,</p>
        <p><strong>{from_name}</strong> wants to connect with you on <strong>Ayu</strong>.</p>
        <p>Click the link below to set up your account and join as their companion:</p>
        <p><a href="{reset_link}" style="background:#4B3425;color:white;padding:12px 24px;border-radius:24px;text-decoration:none;font-weight:bold;">Set up your Ayu account</a></p>
        <p style="color:#999;font-size:13px;">This link expires in {INVITE_EXPIRY_DAYS} days.</p>
        """
    else:
        html_content = f"""
        <p>Hi,</p>
        <p><strong>{from_name}</strong> wants to connect with you on <strong>Ayu</strong>.</p>
        <p>Open the Ayu app to see your companion connection.</p>
        """

    message = Mail(
        from_email=settings.sendgrid_from_email,
        to_emails=to_email,
        subject=f"{from_name} wants to connect with you on Ayu",
        html_content=html_content,
    )

    try:
        sg = sendgrid.SendGridAPIClient(api_key=settings.sendgrid_api_key)
        response = sg.send(message)
        logger.info("Invite email sent to %s, status %s", to_email, response.status_code)
    except Exception:
        logger.exception("Failed to send companion invite email to %s", to_email)


def send_companion_invite(from_uid: str,from_name: str | None,from_email: str | None,
    to_email: str,) -> dict:
    db = get_firestore_client()
    sender_name = from_name or "Your friend"

    # Block if patient already has a companion linked
    sender_doc = db.collection(USERS_COLLECTION).document(from_uid).get()
    sender_data = sender_doc.to_dict() or {}
    if (sender_data.get("patientProfile") or {}).get("companion"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You already have a companion.",
        )

    # create one if the email is not registered
    account_created = False
    reset_link: str | None = None

    try:
        target_user = firebase_auth.get_user_by_email(to_email)
        target_uid = target_user.uid
    except firebase_auth.UserNotFoundError:
        target_user = firebase_auth.create_user(
            email=to_email,
            password=_random_password(),
            email_verified=False,
        )
        target_uid = target_user.uid
        account_created = True

        try:
            # Generate Firebase password reset link so the partner can set their password
            reset_link = firebase_auth.generate_password_reset_link(to_email)
        except Exception:
            logger.exception("Failed to generate password reset link for %s", to_email)

    # Block self invite
    if target_uid == from_uid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot invite yourself.",
        )

    # Create Firestore doc for partner if it doesn't exist yet firebase Auth account existed but never signed into Ayu
    target_ref = db.collection(USERS_COLLECTION).document(target_uid)
    target_doc = target_ref.get()
    if not target_doc.exists:
        target_ref.set({
            "uid": target_uid,
            "email": to_email,
            "role": "companion",
            "accountStatus": "pending",
            "patientUid": from_uid,
            "createdAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        })

    # only unlinked companions or new users are allowed
    target_data = target_doc.to_dict() or {}
    target_role = target_data.get("role")

    if target_role == "doctor":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot invite a doctor as a companion.",
        )

    if target_role == "patient":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This person already has a patient account on Ayu.",
        )

    if target_role == "companion" and target_data.get("patientUid") and target_data.get("patientUid") != from_uid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This person is already a companion to someone else.",
        )

    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(days=INVITE_EXPIRY_DAYS)

    # Clean up old pending invites from this patient to this email for reinvite
    old_invites = (
        db.collection(COMPANION_INVITES_COLLECTION)
        .where("fromUid", "==", from_uid)
        .where("toEmail", "==", to_email)
        .where("status", "==", "pending")
        .stream()
    )
    for old_invite in old_invites:
        old_invite.reference.delete()

    # Record the invite for expiry tracking
    invite_ref = db.collection(COMPANION_INVITES_COLLECTION).document()
    invite_ref.set({
        "fromUid": from_uid,
        "fromName": sender_name,
        "fromEmail": from_email,
        "toEmail": to_email,
        "toUid": target_uid,
        "status": "pending",
        "accountCreated": account_created,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "expiresAt": expires_at,
    })

    # Store companion info inside patient's patientProfile 
    target_name = target_data.get("fullName") or to_email.split("@")[0]
    db.collection(USERS_COLLECTION).document(from_uid).update({
        "patientProfile.companion": {
            "uid": target_uid,
            "email": to_email,
            "name": target_name,
            "avatar": target_data.get("avatar"),
            "status": "pending",
            "linkedAt": firestore.SERVER_TIMESTAMP,
        }
    })

    _send_invite_email(to_email, sender_name, reset_link)

    return {"status": "invited", "invite_id": invite_ref.id}


def _activate_companion_if_pending(uid: str, db) -> None:
    # Called on companion's first login then change status to active on both sides
    companion_doc = db.collection(USERS_COLLECTION).document(uid).get()
    companion_data = companion_doc.to_dict() or {}

    if companion_data.get("accountStatus") != "pending":
        return

    patient_uid = companion_data.get("patientUid")
    if not patient_uid:
        return

    # Mark companion account as active
    db.collection(USERS_COLLECTION).document(uid).update({
        "accountStatus": "active",
    })

    # Mark companion status inside patient's patientProfile as active
    db.collection(USERS_COLLECTION).document(patient_uid).update({
        "patientProfile.companion.status": "active",
    })

    logger.info("Companion %s activated for patient %s", uid, patient_uid)


def resolve_and_check_privacy(companion_uid: str, flag: str) -> str:
    # checks the privacy flag and returns patient_uid if allowed
    db = get_firestore_client()

    companion_doc = db.collection(USERS_COLLECTION).document(companion_uid).get()
    companion_data = companion_doc.to_dict() or {}
    patient_uid = companion_data.get("patientUid")

    if not patient_uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No linked patient found.",
        )

    patient_doc = db.collection(USERS_COLLECTION).document(patient_uid).get()
    privacy = ((patient_doc.to_dict() or {}).get("patientProfile") or {}).get("companionPrivacy") or {}

    flag_map = {
        "mood_journal": privacy.get("moodJournal", True),
        "tracking": privacy.get("tracking", True),
        "doctor_appointments": privacy.get("doctorAppointments", True),
        "todo_list": privacy.get("todoList", False),
    }

    if not flag_map.get(flag, False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Patient has restricted access to this feature.",
        )

    return patient_uid


def save_companion_privacy(uid: str, mood_journal: bool, todo_list: bool, tracking: bool, doctor_appointments: bool) -> dict:
    db = get_firestore_client()

    # Store privacy preferences inside patientProfile
    db.collection(USERS_COLLECTION).document(uid).update({
        "patientProfile.companionPrivacy": {
            "moodJournal": mood_journal,
            "todoList": todo_list,
            "tracking": tracking,
            "doctorAppointments": doctor_appointments,
        }
    })

    return {
        "mood_journal": mood_journal,
        "todo_list": todo_list,
        "tracking": tracking,
        "doctor_appointments": doctor_appointments,
    }


def get_companion_privacy(uid: str, role: str = "patient") -> dict:
    db = get_firestore_client()

    # Companion reads the patient's privacy settings using their patientUid
    if role == "companion":
        companion_doc = db.collection(USERS_COLLECTION).document(uid).get()
        patient_uid = (companion_doc.to_dict() or {}).get("patientUid")
        if not patient_uid:
            return _default_privacy()
        uid = patient_uid

    user_doc = db.collection(USERS_COLLECTION).document(uid).get()
    if not user_doc.exists:
        return _default_privacy()

    privacy = ((user_doc.to_dict() or {}).get("patientProfile") or {}).get("companionPrivacy")
    if not privacy:
        return _default_privacy()

    return {
        "mood_journal": privacy.get("moodJournal", True),
        "todo_list": privacy.get("todoList", False),
        "tracking": privacy.get("tracking", True),
        "doctor_appointments": privacy.get("doctorAppointments", True),
    }


def _default_privacy() -> dict:
    return {
        "mood_journal": True,
        "todo_list": False,
        "tracking": True,
        "doctor_appointments": True,
    }


def get_companion_status(uid: str, role: str = "patient") -> dict:
    db = get_firestore_client()

    user_doc = db.collection(USERS_COLLECTION).document(uid).get()
    if not user_doc.exists:
        return {"has_companion": False, "companion": None}

    user_data = user_doc.to_dict() or {}

    if role == "companion":
        # On first login activate the companion relationship
        _activate_companion_if_pending(uid, db)

        patient_uid = user_data.get("patientUid")
        if not patient_uid:
            return {"has_companion": False, "companion": None}

        patient_doc = db.collection(USERS_COLLECTION).document(patient_uid).get()
        if not patient_doc.exists:
            return {"has_companion": False, "companion": None}

        patient_data = patient_doc.to_dict() or {}
        return {
            "has_companion": True,
            "companion": {
                "uid": patient_uid,
                "email": patient_data.get("email", ""),
                "name": patient_data.get("fullName"),
                "avatar": patient_data.get("avatar"),
                "status": "active",
            },
        }

    # Patient reads companion info from their own patientProfile
    companion = (user_data.get("patientProfile") or {}).get("companion")
    if not companion:
        return {"has_companion": False, "companion": None}

    return {
        "has_companion": True,
        "companion": {
            "uid": companion.get("uid", ""),
            "email": companion.get("email", ""),
            "name": companion.get("name"),
            "avatar": companion.get("avatar"),
            "status": companion.get("status", "pending"),
        },
    }

def unlink_companion(uid: str) -> dict:
    db = get_firestore_client()

    user_doc = db.collection(USERS_COLLECTION).document(uid).get()
    if not user_doc.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )

    user_data = user_doc.to_dict() or {}
    companion = (user_data.get("patientProfile") or {}).get("companion")
    if not companion:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No companion linked.",
        )

    companion_uid = companion.get("uid")

    # Delete from patient's profile
    db.collection(USERS_COLLECTION).document(uid).update({
        "patientProfile.companion": firestore.DELETE_FIELD,
    })

    # Delete from companion's profile if they have a linked record
    if companion_uid:
        db.collection(USERS_COLLECTION).document(companion_uid).update({
            "patientUid": firestore.DELETE_FIELD,
            "accountStatus": firestore.DELETE_FIELD,
        })

    logger.info("Companion %s unlinked from patient %s", companion_uid, uid)
    return {"status": "unlinked"}


def cleanup_expired_invites() -> dict:
    db = get_firestore_client()
    now = datetime.now(timezone.utc)

    expired_docs = (
        db.collection(COMPANION_INVITES_COLLECTION)
        .where("expiresAt", "<", now)
        .where("status", "==", "pending")
        .stream()
    )

    count = 0
    for doc in expired_docs:
        doc.reference.delete()
        count += 1

    logger.info("Cleaned up %d expired companion invites", count)
    return {"cleaned_up": count}
