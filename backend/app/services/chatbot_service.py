import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import HTTPException, status
from firebase_admin import firestore

from app.core.firebase import get_firestore_client
from app.schemas.chatbot import MessageResponse, SessionResponse

logger = logging.getLogger(__name__)

SESSIONS_COLLECTION  = "sessions"
MESSAGES_COLLECTION  = "messages"
USERS_COLLECTION = "users"

def _parse_timestamp(value: Any) -> datetime | None:
    if value is None:
        return None
    if hasattr(value, "timestamp"):
        # force utc to avoid issues with comparisons later
        try:
            return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value
        except Exception:
            return None
    if isinstance(value, datetime):
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value
    return None


def _map_session(doc_id: str, data: dict[str, Any]) -> SessionResponse:
    message_count_raw = data.get("messageCount", 0)
    # handle case where firestore might store numbers as strings
    try:
        message_count = int(message_count_raw)
    except (TypeError, ValueError):
        message_count = 0

    return SessionResponse(
        session_id = doc_id,
        user_id = str(data.get("userId", "")),
        title = str(data.get("title", "")),
        status = str(data.get("status", "active")),
        dominant_emotion= str(data.get("dominantEmotion", "")),
        message_count = message_count,
        created_at = _parse_timestamp(data.get("createdAt")),
        last_message_at = _parse_timestamp(data.get("lastMessageAt")),
        is_summarized = bool(data.get("isSummarized", False)),
    )


def _map_message(doc_id: str, data: dict[str, Any]) -> MessageResponse:
    raw_analysis = data.get("analysis")
    analysis = None

    if isinstance(raw_analysis, dict):
        from app.schemas.chatbot import MessageAnalysis
        # map the nested analysis dict to our local schema
        try:
            analysis = MessageAnalysis(
                emotion_label = str(raw_analysis.get("emotion_label", raw_analysis.get("analysis", ""))),
                safety_flag = str(raw_analysis.get("safety_flag", "non_crisis")),
                suicidal_confidence= float(raw_analysis.get("suicidal_confidence", 0.0)),
                triggered_by = str(raw_analysis.get("triggered_by", "none")),
            )
        except Exception:
            analysis = None

    return MessageResponse(
        message_id = doc_id,
        session_id = str(data.get("sessionId", "")),
        user_id = str(data.get("userId", "")),
        role = str(data.get("role", "")),
        content = str(data.get("content", "")),
        timestamp  = _parse_timestamp(data.get("timestamp")),
        analysis = analysis,
    )

def create_session(uid: str, title: str) -> SessionResponse:
    #Create a new chat session for the patient and return the session data
    db  = get_firestore_client()
    ref = db.collection(SESSIONS_COLLECTION).document()

    data = {
        "userId": uid,
        "title": title.strip(),
        "status": "active",
        "dominantEmotion": "",
        "messageCount": 0,
        "isSummarized": False,
        "createdAt" : firestore.SERVER_TIMESTAMP,
        "lastMessageAt": firestore.SERVER_TIMESTAMP,
    }
    ref.set(data)

    # Read to get the resolved server timestamps
    snapshot = ref.get()
    return _map_session(ref.id, snapshot.to_dict() or {})


def list_sessions(uid: str) -> list[SessionResponse]:
    #Return all sessions belonging to the patient ordered by most recent first
    db = get_firestore_client()
    snapshots = (
        db.collection(SESSIONS_COLLECTION)
        .where("userId", "==", uid)
        .stream()
    )
    sessions = [_map_session(snap.id, snap.to_dict() or {}) for snap in snapshots]
    # sort locally to avoid having to build composite indexes in firestore console
    sessions.sort(key=lambda s: s.last_message_at or datetime.min.replace(tzinfo=timezone.utc), reverse=True)
    return sessions


def get_session(session_id: str, uid: str) -> dict[str, Any]:
    db = get_firestore_client()
    snapshot = db.collection(SESSIONS_COLLECTION).document(session_id).get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found.",
        )
    data = snapshot.to_dict() or {}
    # check that the session actually belongs to the requesting user
    if data.get("userId") != uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You cannot access this session.",
        )

    return data

def get_conversation_history(session_id: str) -> list[dict[str, str]]:
    #Return the last 6 messages in chronological order to build the conversation context passed to Gemini
   
    db = get_firestore_client()
    # order_by with where requires a composite index — sort in Python instead
    snapshots = (
        db.collection(MESSAGES_COLLECTION)
        .where("sessionId", "==", session_id)
        .stream()
    )
    messages = [snap.to_dict() or {} for snap in snapshots]

    # Sort chronologically using the timestamp field
    def _ts_key(msg: dict) -> datetime:
        ts = _parse_timestamp(msg.get("timestamp"))
        return ts if ts is not None else datetime.min.replace(tzinfo=timezone.utc)

    messages.sort(key=_ts_key)

    # Keep only the last 10 for the prompt context
    messages = messages[-6:]

    return [
        {"role": str(msg.get("role", "")), "content": str(msg.get("content", ""))}
        for msg in messages
    ]


def get_user_emotion_history(session_id: str) -> list[str]:
    # Collect all emotion labels recorded for patient messages in this sessio to build the user_summary

    db = get_firestore_client()
    # Filter on sessionId only
    snapshots = (
        db.collection(MESSAGES_COLLECTION)
        .where("sessionId", "==", session_id)
        .stream()
    )
    emotions: list[str] = []
    for snap in snapshots:
        data = snap.to_dict() or {}
        if data.get("role") != "patient":
            continue
        analysis = data.get("analysis")
        if isinstance(analysis, dict):
            label = analysis.get("emotion_label") or analysis.get("analysis", "")
            if label:
                emotions.append(str(label))
    return emotions


def get_crisis_count(session_id: str) -> int:
    #Count the number of crisis flagged patient messages in this session
    db = get_firestore_client()
    # Filter on sessionId only and check role
    snapshots = (
        db.collection(MESSAGES_COLLECTION)
        .where("sessionId", "==", session_id)
        .stream()
    )
    count = 0
    for snap in snapshots:
        data = snap.to_dict() or {}
        if data.get("role") != "patient":
            continue
        analysis = data.get("analysis")
        if isinstance(analysis, dict) and analysis.get("safety_flag") == "crisis":
            count += 1
    return count


def save_patient_message(session_id: str,uid: str,content : str,
    analysis : dict[str, Any],) -> str:
    #Save the patient's message with its analysis maps and return the new doc id
    db = get_firestore_client()
    ref = db.collection(MESSAGES_COLLECTION).document()

    ref.set({
        "sessionId": session_id,
        "userId": uid,
        "role" : "patient",
        "content": content,
        "timestamp": firestore.SERVER_TIMESTAMP,
        "analysis": {
            "emotion_label": analysis.get("emotion_label", ""),
            "safety_flag" : analysis.get("safety_flag", "non_crisis"),
            "suicidal_confidence": float(analysis.get("suicidal_confidence", 0.0)),
            "triggered_by": analysis.get("triggered_by", "none"),
        },
    })
    return ref.id


def save_chatbot_message(session_id: str, uid: str, content: str) -> str:
    #Save Ayu's response message and returns the new doc id
    db= get_firestore_client()
    ref = db.collection(MESSAGES_COLLECTION).document()

    ref.set({
        "sessionId": session_id,
        "userId": uid,
        "role" : "chatbot",
        "content": content,
        "timestamp": firestore.SERVER_TIMESTAMP,
    })
    return ref.id


def update_session_stats(session_id: str,dominant_emotion: str,message_count: int,) -> None:
    # update session metadata after each message exchange
    db= get_firestore_client()
    ref = db.collection(SESSIONS_COLLECTION).document(session_id)

    ref.update({
        "dominantEmotion": dominant_emotion,
        "messageCount": message_count,
        "lastMessageAt": firestore.SERVER_TIMESTAMP,
    })


def get_user_profile(uid: str) -> dict[str, Any]:
    # Fetch the patient's Firestore user document for context passing"
    db = get_firestore_client()
    snapshot = db.collection(USERS_COLLECTION).document(uid).get()

    if not snapshot.exists:
        return {}

    return snapshot.to_dict() or {}


def get_long_term_summary(uid: str) -> str:
    # Read the patient's longTermSummary from their user document
    profile = get_user_profile(uid)
    return str(profile.get("patientProfile", {}).get("longTermSummary", ""))


def update_long_term_summary(uid: str, summary: str) -> None:
    # Persist the updated longTermSummary inside patientProfile on the user document

    db = get_firestore_client()
    db.collection(USERS_COLLECTION).document(uid).update({
        "patientProfile.longTermSummary": summary,
    })


def write_context_snapshot(session_id: str, snapshot_text: str) -> None:
    # records the patient's history at start time so future updates don't change this session's context
    db = get_firestore_client()
    db.collection(SESSIONS_COLLECTION).document(session_id).update({
        "contextSnapshot": snapshot_text,
    })


def mark_session_summarized(session_id: str) -> None:
    # isSummarized to True once the longTermSummary update succeeds
    db = get_firestore_client()
    db.collection(SESSIONS_COLLECTION).document(session_id).update({
        "isSummarized": True,
    })


def get_unsummarized_sessions(uid: str) -> list[dict]:
    #finds non empty pending sessions that need to be processed for the longterm summary
    db = get_firestore_client()
    snapshots = (
        db.collection(SESSIONS_COLLECTION)
        .where("userId", "==", uid)
        .where("isSummarized", "==", False)
        .stream()
    )
    results = []
    for snap in snapshots:
        data = snap.to_dict() or {}
        # Skip empty sessions
        try:
            if int(data.get("messageCount", 0)) == 0:
                continue
        except (TypeError, ValueError):
            continue
        results.append({"session_id": snap.id, **data})
    return results


def list_messages(session_id: str) -> list[MessageResponse]:
    # fetches the full chat history sorted from oldest to newest
    db= get_firestore_client()
    snapshots = (
        db.collection(MESSAGES_COLLECTION)
        .where("sessionId", "==", session_id)
        .stream()
    )
    messages = [_map_message(snap.id, snap.to_dict() or {}) for snap in snapshots]
    messages.sort(key=lambda m: m.timestamp or datetime.min.replace(tzinfo=timezone.utc))
    return messages
