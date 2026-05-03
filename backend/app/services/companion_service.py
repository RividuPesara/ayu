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


def get_companion_status(uid: str) -> dict:
    db = get_firestore_client()

    user_doc = db.collection(USERS_COLLECTION).document(uid).get()
    if not user_doc.exists:
        return {"has_companion": False, "companion": None}

    # Companion data is inside patientProfile
    companion = ((user_doc.to_dict() or {}).get("patientProfile") or {}).get("companion")
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
