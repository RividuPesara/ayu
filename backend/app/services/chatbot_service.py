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
CONVERSATION_HISTORY_LIMIT = 6
DEFAULT_MESSAGES_PAGE_SIZE = 50
MAX_MESSAGES_PAGE_SIZE = 200


def _safe_int(value: Any, default: int = 0) -> int:
    # Safely convert a value to integer or return a default if conversion fails
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _normalize_emotion_counts(value: Any) -> dict[str, int]:
    # Make sure emotion dictionary contains valid strings and positive integers
    if not isinstance(value, dict):
        return {}

    normalized: dict[str, int] = {}
    for raw_label, raw_count in value.items():
        label = str(raw_label).strip()
        if not label:
            continue
        count = _safe_int(raw_count, 0)
        if count > 0:
            normalized[label] = count
    return normalized


def _dominant_emotion_from_counts(emotion_counts: dict[str, int]) -> str:
    # Identify the emotion with the highest frequency in the counts dictionary
    if not emotion_counts:
        return ""
    return max(emotion_counts.items(), key=lambda item: (item[1], item[0]))[0]


def _build_session_aggregates(data: dict[str, Any]) -> dict[str, Any]:
    # Extract and clean session level statistics from Firestore raw data
    emotion_counts = _normalize_emotion_counts(data.get("emotionCounts"))
    patient_message_count = _safe_int(
        data.get("patientMessageCount", data.get("messageCount", sum(emotion_counts.values()))),
        0,
    )
    crisis_count = _safe_int(data.get("crisisCount", 0), 0)

    # Sanity check to prevent negative counts
    if patient_message_count < 0:
        patient_message_count = 0
    if crisis_count < 0:
        crisis_count = 0

    dominant_emotion = str(data.get("dominantEmotion", "")).strip()
    if not dominant_emotion:
        dominant_emotion = _dominant_emotion_from_counts(emotion_counts)

    return {
        "emotion_counts": emotion_counts,
        "patient_message_count": patient_message_count,
        "crisis_count": crisis_count,
        "dominant_emotion": dominant_emotion,
    }


def _recompute_session_aggregates(session_id: str) -> dict[str, Any]:
    # Scan all session messages to rebuild statistics if they are missing from the session doc
    db = get_firestore_client()
    snapshots = (
        db.collection(MESSAGES_COLLECTION)
        .where("sessionId", "==", session_id)
        .stream()
    )

    emotion_counts: dict[str, int] = {}
    patient_message_count = 0
    crisis_count = 0

    for snap in snapshots:
        data = snap.to_dict() or {}
        if data.get("role") != "patient":
            continue

        patient_message_count += 1

        analysis = data.get("analysis")
        if not isinstance(analysis, dict):
            continue

        label = str(analysis.get("emotion_label") or analysis.get("analysis", "")).strip()
        if label:
            emotion_counts[label] = emotion_counts.get(label, 0) + 1

        if str(analysis.get("safety_flag", "")).lower() == "crisis":
            crisis_count += 1

    dominant_emotion = _dominant_emotion_from_counts(emotion_counts)
    # Sync the recomputed values back to the session documen
    db.collection(SESSIONS_COLLECTION).document(session_id).update({
        "emotionCounts": emotion_counts,
        "patientMessageCount": patient_message_count,
        "crisisCount": crisis_count,
        "dominantEmotion": dominant_emotion,
        "messageCount": patient_message_count,
    })

    return {
        "emotion_counts": emotion_counts,
        "patient_message_count": patient_message_count,
        "crisis_count": crisis_count,
        "dominant_emotion": dominant_emotion,
    }

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
        "patientMessageCount": 0,
        "crisisCount": 0,
        "emotionCounts": {},
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
        .where("status", "==", "active")
        .order_by("lastMessageAt", direction=firestore.Query.DESCENDING)
        .stream()
    )
    return [_map_session(snap.id, snap.to_dict() or {}) for snap in snapshots]


def get_session_aggregates(session_id: str) -> dict[str, Any]:
    # Fetch existing session stats if data is incomplete
    db = get_firestore_client()
    snapshot = db.collection(SESSIONS_COLLECTION).document(session_id).get()
    if not snapshot.exists:
        return {
            "emotion_counts": {},
            "patient_message_count": 0,
            "crisis_count": 0,
            "dominant_emotion": "",
        }

    data = snapshot.to_dict() or {}
    has_aggregates = (
        isinstance(data.get("emotionCounts"), dict)
        and data.get("patientMessageCount") is not None
        and data.get("crisisCount") is not None
    )
    if has_aggregates:
        return _build_session_aggregates(data)

    return _recompute_session_aggregates(session_id)


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
    snapshots = list(
        db.collection(MESSAGES_COLLECTION)
        .where("sessionId", "==", session_id)
        .order_by("timestamp", direction=firestore.Query.DESCENDING)
        .limit(CONVERSATION_HISTORY_LIMIT)
        .stream()
    )

    # Query returns newest to first, reverse so the prompt sees oldest to newest
    snapshots.reverse()
    messages = [snap.to_dict() or {} for snap in snapshots]

    return [
        {"role": str(msg.get("role", "")), "content": str(msg.get("content", ""))}
        for msg in messages
    ]


def get_user_emotion_history(session_id: str) -> list[str]:
    # Backward compatible helper reconstructed from session aggregates
    aggregate = get_session_aggregates(session_id)
    emotion_counts = aggregate["emotion_counts"]
    emotions: list[str] = []
    for label, count in emotion_counts.items():
        emotions.extend([label] * count)
    return emotions


def get_crisis_count(session_id: str) -> int:
    # Reads from session level aggregate instead of scanning message history
    aggregate = get_session_aggregates(session_id)
    return int(aggregate["crisis_count"])


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


def update_session_stats(session_id: str, emotion_label: str, safety_flag: str) -> None:
    # Increment aggregate counters after each saved patient message
    db = get_firestore_client()
    ref = db.collection(SESSIONS_COLLECTION).document(session_id)

    @firestore.transactional
    def _apply_updates(transaction: firestore.Transaction) -> None:
        snapshot = ref.get(transaction=transaction)
        if not snapshot.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Session not found.",
            )

        data = snapshot.to_dict() or {}
        aggregates = _build_session_aggregates(data)
        emotion_counts = dict(aggregates["emotion_counts"])

        clean_emotion = str(emotion_label).strip()
        if clean_emotion:
            emotion_counts[clean_emotion] = emotion_counts.get(clean_emotion, 0) + 1

        patient_message_count = int(aggregates["patient_message_count"]) + 1
        crisis_count = int(aggregates["crisis_count"])
        if str(safety_flag).lower() == "crisis":
            crisis_count += 1

        dominant_emotion = _dominant_emotion_from_counts(emotion_counts)

        transaction.update(ref, {
            "dominantEmotion": dominant_emotion,
            "messageCount": patient_message_count,
            "patientMessageCount": patient_message_count,
            "crisisCount": crisis_count,
            "emotionCounts": emotion_counts,
            "lastMessageAt": firestore.SERVER_TIMESTAMP,
        })

    _apply_updates(db.transaction())


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


def archive_session(session_id: str) -> None:
    # delete a session by marking it archived.
    db = get_firestore_client()
    db.collection(SESSIONS_COLLECTION).document(session_id).update({
        "status": "archived",
        "archivedAt": firestore.SERVER_TIMESTAMP,
    })


def archive_all_sessions(uid: str) -> int:
    # delete all user sessions in batches
    db = get_firestore_client()
    snapshots = (
        db.collection(SESSIONS_COLLECTION)
        .where("userId", "==", uid)
        .stream()
    )

    archived_count = 0
    batch = db.batch()
    pending_writes = 0

    for snap in snapshots:
        data = snap.to_dict() or {}
        if str(data.get("status", "active")).lower() == "archived":
            continue

        batch.update(snap.reference, {
            "status": "archived",
            "archivedAt": firestore.SERVER_TIMESTAMP,
        })
        archived_count += 1
        pending_writes += 1

        if pending_writes >= 450:
            batch.commit()
            batch = db.batch()
            pending_writes = 0

    if pending_writes > 0:
        batch.commit()

    return archived_count


def get_unsummarized_sessions(uid: str) -> list[dict]:
    #finds non empty pending sessions that need to be processed for the longterm summary
    db = get_firestore_client()
    snapshots = (
        db.collection(SESSIONS_COLLECTION)
        .where("userId", "==", uid)
        .where("isSummarized", "==", False)
        .where("status", "==", "active")
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


def list_messages(
    session_id: str,
    limit: int = DEFAULT_MESSAGES_PAGE_SIZE,
    start_after: str | None = None,
) -> list[MessageResponse]:
    # Fetch paginated history with newest page first, then return each page oldest to newest
    db = get_firestore_client()
    page_size = max(1, min(limit, MAX_MESSAGES_PAGE_SIZE))

    query = (
        db.collection(MESSAGES_COLLECTION)
        .where("sessionId", "==", session_id)
        .order_by("timestamp", direction=firestore.Query.DESCENDING)
    )

    if start_after:
        cursor_snapshot = db.collection(MESSAGES_COLLECTION).document(start_after).get()
        if not cursor_snapshot.exists:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid start_after cursor.",
            )

        cursor_data = cursor_snapshot.to_dict() or {}
        if cursor_data.get("sessionId") != session_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cursor does not belong to this session.",
            )

        query = query.start_after(cursor_snapshot)

    snapshots = list(query.limit(page_size).stream())
    snapshots.reverse()
    return [_map_message(snap.id, snap.to_dict() or {}) for snap in snapshots]
