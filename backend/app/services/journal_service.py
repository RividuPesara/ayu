import logging
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo

from fastapi import HTTPException, status
from firebase_admin import firestore

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.schemas.journal import JournalEntryResponse, MoodHistoryItem
from app.services.sentiment_service import analyze_safety

logger = logging.getLogger(__name__)

DAILY_PULSES_COLLECTION = "daily_pulses"
JOURNALS_COLLECTION = "journals"
SESSIONS_COLLECTION = "sessions"
USERS_COLLECTION = "users"

_CANONICAL_MOODS = {"Normal", "Anxiety", "Stress", "Depression", "Suicidal"}
_LOW_MOOD_KEYS = {"Anxiety", "Stress", "Depression"}


def _get_user_timezone() -> ZoneInfo:
    # Resolve configured timezone and fallback to UTC if invalid
    settings = get_settings()
    try:
        return ZoneInfo(settings.dashboard_timezone)
    except Exception:
        return ZoneInfo("UTC")


def _parse_timestamp(value: Any) -> datetime | None:
    if isinstance(value, datetime):
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value

    if hasattr(value, "timestamp"):
        try:
            if value.tzinfo is None:
                return value.replace(tzinfo=timezone.utc)
            return value
        except Exception:
            return None

    return None


def _normalize_mood(raw_mood: str, *, strict: bool = False) -> str:
    # validate input against allowed mood constants
    mood_value = str(raw_mood).strip()

    if mood_value in _CANONICAL_MOODS:
        return mood_value

    if strict:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported mood value.",
        )

    return "Normal"


def _resolve_ai_mood(raw_mood: str) -> str:
    # AI labels are normalized into the same class names as user moods
    return _normalize_mood(raw_mood, strict=False)


def _safe_int(value: Any, default: int = 0) -> int:
    # Handle null database values safely
    try:
        return int(value)
    except Exception:
        return default


def _current_local_date_key() -> str:
    local_now = datetime.now(tz=_get_user_timezone())
    return local_now.strftime("%Y-%m-%d")


def _day_bounds_utc(date_key: str) -> tuple[datetime, datetime]:
    # Build UTC boundaries for the configured local day.
    tz = _get_user_timezone()
    local_start = datetime.strptime(date_key, "%Y-%m-%d").replace(tzinfo=tz)
    local_end = local_start + timedelta(days=1)
    return local_start.astimezone(timezone.utc), local_end.astimezone(timezone.utc)


def _map_journal_entry(
    doc_id: str,
    data: dict[str, Any],
    *,
    include_content: bool = True,) -> JournalEntryResponse:
    # Transform raw Firestore dictionary into a structured Pydantic response
    return JournalEntryResponse(
        entry_id=doc_id,
        user_id=str(data.get("userId", "")),
        title=str(data.get("title", "")),
        content=str(data.get("content", "")) if include_content else "",
        user_mood=str(data.get("userMood", "Normal")),
        ai_mood=str(data.get("aiMood", "pending")),
        is_mismatch=bool(data.get("isMismatch", False)),
        safety_flag=str(data.get("safetyFlag", "non_crisis")),
        entry_date=_parse_timestamp(data.get("entryDate")),
    )


def list_journal_entries(uid: str, limit: int = 50, descending: bool = True) -> list[JournalEntryResponse]:
    # query for the most recent journal entries for a specific user
    db = get_firestore_client()
    direction = firestore.Query.DESCENDING if descending else firestore.Query.ASCENDING

    snapshots = (
        db.collection(JOURNALS_COLLECTION)
        .where("userId", "==", uid)
        .order_by("entryDate", direction=direction)
        .limit(limit)
        .stream()
    )

    return [_map_journal_entry(snap.id, snap.to_dict() or {}) for snap in snapshots]


def list_journal_entries_page(
    uid: str,
    limit: int = 4,
    descending: bool = True,
    start_after: str | None = None,
    include_content: bool = False,
) -> dict[str, Any]:
    # Use pagination to avoid large document offsets and high read costs
    db = get_firestore_client()
    direction = firestore.Query.DESCENDING if descending else firestore.Query.ASCENDING

    query = (
        db.collection(JOURNALS_COLLECTION)
        .where("userId", "==", uid)
        .order_by("entryDate", direction=direction)
    )

    if start_after:
        cursor_snapshot = db.collection(JOURNALS_COLLECTION).document(start_after).get()
        if cursor_snapshot.exists:
            query = query.start_after(cursor_snapshot)

    # Fetch N+1 items to check if another page follows
    snapshots = list(query.limit(limit + 1).stream())
    has_more = len(snapshots) > limit
    visible = snapshots[:limit]

    entries = [
        _map_journal_entry(snap.id, snap.to_dict() or {}, include_content=include_content)
        for snap in visible
    ]
    next_cursor = entries[-1].entry_id if has_more and entries else None

    return {
        "entries": entries,
        "next_cursor": next_cursor,
        "has_more": has_more,
    }


def get_journal_entry(uid: str, entry_id: str) -> JournalEntryResponse:
    # Read full journal content only when user opens a specific entry
    db = get_firestore_client()
    snapshot = db.collection(JOURNALS_COLLECTION).document(entry_id).get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Journal entry not found.",
        )

    data = snapshot.to_dict() or {}
    if str(data.get("userId", "")) != uid:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Journal entry not found.",
        )

    return _map_journal_entry(entry_id, data, include_content=True)


def list_recent_mood_history(uid: str, limit: int = 4) -> list[MoodHistoryItem]:
    # Read lightweight history cards from most recent journal entries
    entries = list_journal_entries(uid, limit=limit, descending=True)
    history: list[MoodHistoryItem] = []

    for entry in entries:
        timestamp = entry.entry_date
        if timestamp is None:
            local_date = datetime.now(tz=_get_user_timezone())
        else:
            local_date = timestamp.astimezone(_get_user_timezone())

        history.append(
            MoodHistoryItem(
                month=local_date.strftime("%b").upper(),
                day=local_date.strftime("%d"),
                title=entry.title,
                mood=entry.user_mood.upper(),
            )
        )

    return history


def _increment_active_day_if_needed(uid: str, date_key: str) -> dict[str, Any]:
    # Increment daily counters on the users document once per day
    db = get_firestore_client()
    ref = db.collection(USERS_COLLECTION).document(uid)
    transaction = db.transaction()
    result = {
        "incremented": False,
        "total_days": 0,
        "journal_streak": 0,
        "last_journal_date": "",
    }

    @firestore.transactional
    def _apply_updates(tx: firestore.Transaction) -> None:
        snapshot = ref.get(transaction=tx)
        data = snapshot.to_dict() or {}

        last_date = str(data.get("lastJournalDate", "")).strip()
        total_days = _safe_int(data.get("totalDays"), default=_safe_int(data.get("daysCount"), default=0))
        streak = _safe_int(data.get("journalStreak"), default=0)
        # Skip updates if user has already journaled today
        if last_date == date_key:
            result.update(
                {
                    "incremented": False,
                    "total_days": total_days,
                    "journal_streak": streak,
                    "last_journal_date": last_date,
                }
            )
            return
        # Check if today is exactly one day after last session to increment streak
        next_streak = 1
        if last_date:
            try:
                previous_date = datetime.strptime(last_date, "%Y-%m-%d").date()
                current_date = datetime.strptime(date_key, "%Y-%m-%d").date()
                if (current_date - previous_date).days == 1:
                    next_streak = streak + 1
            except Exception:
                next_streak = 1

        next_total_days = total_days + 1
        tx.set(
            ref,
            {
                "totalDays": next_total_days,
                "daysCount": next_total_days,
                "journalStreak": next_streak,
                "lastJournalDate": date_key,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )

        result.update(
            {
                "incremented": True,
                "total_days": next_total_days,
                "journal_streak": next_streak,
                "last_journal_date": date_key,
            }
        )

    _apply_updates(transaction)
    return result


def _get_user_day_counters(uid: str) -> dict[str, Any]:
    db = get_firestore_client()
    snapshot = db.collection(USERS_COLLECTION).document(uid).get()
    data = snapshot.to_dict() or {}

    return {
        "active_days_count": _safe_int(data.get("totalDays"), default=_safe_int(data.get("daysCount"), default=0)),
        "journal_streak": _safe_int(data.get("journalStreak"), default=0),
        "last_active_date_key": str(data.get("lastJournalDate", "")).strip(),
    }


def _collect_today_sources(uid: str) -> dict[str, Any]:
    # Collect source availability and safety flags for today's status
    db = get_firestore_client()

    date_key = _current_local_date_key()
    start_utc, end_utc = _day_bounds_utc(date_key)

    pulse_doc_id = f"{uid}_{date_key}"
    pulse_snapshot = db.collection(DAILY_PULSES_COLLECTION).document(pulse_doc_id).get()
    pulse_recorded_today = pulse_snapshot.exists
    # Check for crisis flags in today's journal entries
    journal_snapshots = (
        db.collection(JOURNALS_COLLECTION)
        .where("userId", "==", uid)
        .where("entryDate", ">=", start_utc)
        .where("entryDate", "<", end_utc)
        .order_by("entryDate", direction=firestore.Query.DESCENDING)
        .stream()
    )

    journal_crisis = False
    has_journal_today = False

    for snapshot in journal_snapshots:
        has_journal_today = True
        data = snapshot.to_dict() or {}
        if str(data.get("safetyFlag", "non_crisis")).lower() == "crisis":
            journal_crisis = True
    # Check for active crisis triggers in chat sessions
    session_snapshots = (
        db.collection(SESSIONS_COLLECTION)
        .where("userId", "==", uid)
        .where("lastMessageAt", ">=", start_utc)
        .where("lastMessageAt", "<", end_utc)
        .order_by("lastMessageAt", direction=firestore.Query.DESCENDING)
        .stream()
    )

    chat_crisis = False
    has_chat_today = False
    for snapshot in session_snapshots:
        data = snapshot.to_dict() or {}
        if str(data.get("status", "active")).lower() != "active":
            continue

        has_chat_today = True

        if int(data.get("crisisCount", 0)) > 0:
            chat_crisis = True

    active_sources: list[str] = []
    if pulse_recorded_today:
        active_sources.append("pulse")
    if has_journal_today:
        active_sources.append("journal")
    if has_chat_today:
        active_sources.append("chat")

    return {
        "active_sources": active_sources,
        "pulse_recorded_today": pulse_recorded_today,
        "journal_crisis": journal_crisis,
        "chat_crisis": chat_crisis,
    }


def _dominant_emotion_from_recent(uid: str, limit: int = 5) -> str:
    # find the most frequent mood across recent history
    entries = list_journal_entries(uid, limit=limit, descending=True)
    if not entries:
        return "Normal"

    counts: dict[str, int] = defaultdict(int)
    for entry in entries:
        mood = _normalize_mood(entry.user_mood, strict=False)
        counts[mood] += 1

    if not counts:
        return "Normal"

    return max(counts, key=counts.get)


def _dominant_emotion_display(mood_key: str) -> str:
    # Map dominant mood into a display label without crisis override
    if mood_key == "Suicidal":
        return "Fragile"
    if mood_key in _LOW_MOOD_KEYS:
        return "Mainly Low"
    return "Mainly Neutral"


def _dominant_emotion_message(label: str) -> str:
    # Contextual supportive messaging based on current mood state
    if label == "Fragile":
        return "Please reach out to a trusted person and seek support right now."
    if label == "Mainly Low":
        return "You seem under strain. Try lighter routines and small recovery breaks today."
    return "Your mood looks steady. Keep checking in and journaling consistently."


def compute_and_store_mood_stats(uid: str) -> dict[str, Any]:
    # Build and persist mood status focused on dominant emotion and fragile safety state
    today_sources = _collect_today_sources(uid)
    active_sources = list(today_sources.get("active_sources", []))

    has_crisis = bool(today_sources.get("chat_crisis", False)) or bool(
        today_sources.get("journal_crisis", False)
    )
    pulse_recorded_today = bool(today_sources.get("pulse_recorded_today", False))

    dominant_key = _dominant_emotion_from_recent(uid)
    dominant_emotion = _dominant_emotion_display(dominant_key)
    emotion_message = _dominant_emotion_message(dominant_emotion)

    counters = _get_user_day_counters(uid)
    active_days_count = _safe_int(counters.get("active_days_count"), default=0)
    journal_streak = _safe_int(counters.get("journal_streak"), default=0)
    last_active_date_key = str(counters.get("last_active_date_key", "")).strip()

    composite_status = dominant_emotion
    status_label = f"Status: {dominant_emotion}"

    mood_stats = {
        "currentStatus": composite_status,
        "compositeStatus": composite_status,
        "statusLabel": status_label,
        "dominantEmotion": dominant_emotion,
        "emotionMessage": emotion_message,
        "pulseRecordedToday": pulse_recorded_today,
        "activeDaysCount": active_days_count,
        "journalStreak": journal_streak,
        "lastActiveDateKey": last_active_date_key,
        "hasCrisis": has_crisis,
        "activeSources": active_sources,
    }

    db = get_firestore_client()
    db.collection(USERS_COLLECTION).document(uid).set(
        {
            "moodStats": mood_stats,
            "currentStatus": composite_status,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )

    return mood_stats


def _build_mood_stats_api_payload(mood_stats: dict[str, Any], recent_history: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "current_status": str(mood_stats.get("currentStatus", "Mainly Neutral")),
        "composite_status": str(mood_stats.get("compositeStatus", "Mainly Neutral")),
        "status_label": str(mood_stats.get("statusLabel", "")),
        "dominant_emotion": str(mood_stats.get("dominantEmotion", "Mainly Neutral")),
        "emotion_message": str(mood_stats.get("emotionMessage", "")),
        "pulse_recorded_today": bool(mood_stats.get("pulseRecordedToday", False)),
        "active_days_count": _safe_int(mood_stats.get("activeDaysCount"), default=0),
        "journal_streak": _safe_int(mood_stats.get("journalStreak"), default=0),
        "last_active_date_key": str(mood_stats.get("lastActiveDateKey", "")),
        "has_crisis": bool(mood_stats.get("hasCrisis", False)),
        "recent_history": recent_history,
    }


def record_daily_pulse(uid: str, mood: str) -> dict[str, Any]:
    # Save daily anchor pulse once per day and refresh status
    normalized_mood = _normalize_mood(mood, strict=True)
    date_key = _current_local_date_key()
    pulse_doc_id = f"{uid}_{date_key}"

    db = get_firestore_client()
    pulse_ref = db.collection(DAILY_PULSES_COLLECTION).document(pulse_doc_id)
    pulse_snapshot = pulse_ref.get()

    if not pulse_snapshot.exists:
        pulse_ref.set(
            {
                "userId": uid,
                "mood": normalized_mood,
                "timestamp": firestore.SERVER_TIMESTAMP,
                "dateKey": date_key,
            },
            merge=True,
        )
        pulse_snapshot = pulse_ref.get()

    mood_stats = compute_and_store_mood_stats(uid)
    recent_history = [item.model_dump() for item in list_recent_mood_history(uid)]
    pulse_data = pulse_snapshot.to_dict() or {}

    return {
        "pulse": {
            "pulse_id": pulse_doc_id,
            "mood": str(pulse_data.get("mood", normalized_mood)),
            "timestamp": _parse_timestamp(pulse_data.get("timestamp")),
        },
        "mood_stats": _build_mood_stats_api_payload(mood_stats, recent_history),
    }


def create_journal_entry(uid: str, title: str, content: str, user_mood: str) -> dict[str, Any]:
    # Persist journal entry immediately and return the real Firestore id
    clean_title = title.strip()
    clean_content = content.strip()

    if not clean_title or not clean_content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Title and content are required.",
        )

    normalized_user_mood = _normalize_mood(user_mood, strict=True)
    date_key = _current_local_date_key()

    db = get_firestore_client()
    ref = db.collection(JOURNALS_COLLECTION).document()

    response_entry = JournalEntryResponse(
        entry_id=ref.id,
        user_id=uid,
        title=clean_title,
        content=clean_content,
        user_mood=normalized_user_mood,
        ai_mood="pending",
        is_mismatch=False,
        safety_flag="non_crisis",
        entry_date=datetime.now(tz=timezone.utc),
    )

    ref.set(
        {
            "userId": uid,
            "title": clean_title,
            "content": clean_content,
            "userMood": normalized_user_mood,
            "aiMood": "pending",
            "isMismatch": False,
            "safetyFlag": "non_crisis",
            "analysisStatus": "queued",
            "dateKey": date_key,
            "entryDate": firestore.SERVER_TIMESTAMP,
        }
    )

    counter_update = _increment_active_day_if_needed(uid, date_key)

    return {
        "entry": response_entry,
        "queued": True,
        "active_days_count": _safe_int(counter_update.get("total_days"), default=0),
        "journal_streak": _safe_int(counter_update.get("journal_streak"), default=0),
        "day_incremented": bool(counter_update.get("incremented", False)),
        "last_active_date_key": str(counter_update.get("last_journal_date", date_key)),
    }


def process_journal_entry_background(uid: str, entry_id: str) -> None:
    # Run sentiment analysis and synthesis updates after instant save response
    try:
        db = get_firestore_client()
        ref = db.collection(JOURNALS_COLLECTION).document(entry_id)
        snapshot = ref.get()

        if not snapshot.exists:
            return

        data = snapshot.to_dict() or {}
        if str(data.get("userId", "")) != uid:
            return

        content = str(data.get("content", "")).strip()
        if not content:
            ref.update(
                {
                    "analysisStatus": "failed",
                    "processedAt": firestore.SERVER_TIMESTAMP,
                }
            )
            return

        analysis = analyze_safety(content)
        ai_label = str(analysis.get("emotion_label", "Normal"))
        normalized_ai_mood = _resolve_ai_mood(ai_label)
        normalized_user_mood = _normalize_mood(str(data.get("userMood", "Normal")), strict=False)

        is_mismatch = normalized_user_mood != normalized_ai_mood
        safety_flag = str(analysis.get("safety_flag", "non_crisis"))

        ref.update(
            {
                "aiMood": normalized_ai_mood,
                "isMismatch": is_mismatch,
                "safetyFlag": safety_flag,
                "analysisStatus": "done",
                "processedAt": firestore.SERVER_TIMESTAMP,
            }
        )

        compute_and_store_mood_stats(uid)
    except Exception:
        logger.exception("Background journal processing failed for entry %s", entry_id)
        try:
            db = get_firestore_client()
            db.collection(JOURNALS_COLLECTION).document(entry_id).set(
                {
                    "analysisStatus": "failed",
                    "processedAt": firestore.SERVER_TIMESTAMP,
                },
                merge=True,
            )
        except Exception:
            logger.exception("Could not store failed background status for entry %s", entry_id)


def get_mood_stats(uid: str) -> dict[str, Any]:
    # Return fresh synthesis values with recent mood history cards
    mood_stats = compute_and_store_mood_stats(uid)
    recent_history = [item.model_dump() for item in list_recent_mood_history(uid)]

    return _build_mood_stats_api_payload(mood_stats, recent_history)
