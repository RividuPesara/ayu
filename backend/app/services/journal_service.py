import logging
import math
from datetime import datetime, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo

from fastapi import HTTPException, status
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.core.redis_client import get_redis
from app.schemas.journal import JournalEntryResponse, MoodHistoryItem
from app.services.sentiment_service import analyze_safety
from app.services.notification_service import send_push

_PROCESSING_KEY_PREFIX = "ayu:journal:processing:"
_PROCESSING_TTL = 90  # covers worstcase analysis time

logger = logging.getLogger(__name__)

DAILY_PULSES_COLLECTION = "daily_pulses"
JOURNALS_COLLECTION = "journals"
SESSIONS_COLLECTION = "sessions"
USERS_COLLECTION = "users"

_CANONICAL_MOODS = {"Normal", "Anxiety", "Stress", "Depression", "Suicidal"}
_LOW_MOOD_KEYS = {"Anxiety", "Stress", "Depression"}

_MOOD_RISK: dict[str, float] = {
    "Normal": 0.0,
    "Anxiety": 1.0,
    "Stress": 1.0,
    "Depression": 2.0,
    "Suicidal": 3.0,
}
_DECAY_LAMBDA = 0.3
_SOURCE_WEIGHT_AI_MOOD = 1.5
_SOURCE_WEIGHT_USER_MOOD = 1.0
_SOURCE_WEIGHT_CHAT = 0.8
_SCORE_FRAGILE = 1.5
_SCORE_LOW = 0.7


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
        .where(filter=FieldFilter("userId", "==", uid))
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
        .where(filter=FieldFilter("userId", "==", uid))
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


_CRISIS_SCORE_THRESHOLD = 2.0


def _collect_today_sources(uid: str) -> dict[str, Any]:
    # compute a today-only weighted score to determine crisis state without time decay
    db = get_firestore_client()

    date_key = _current_local_date_key()
    start_utc, end_utc = _day_bounds_utc(date_key)

    pulse_doc_id = f"{uid}_{date_key}"
    pulse_recorded_today = db.collection(DAILY_PULSES_COLLECTION).document(pulse_doc_id).get().exists

    # Score today's journal entries using same risk values — no decay since all are from today
    journal_snapshots = (
        db.collection(JOURNALS_COLLECTION)
        .where(filter=FieldFilter("userId", "==", uid))
        .where(filter=FieldFilter("entryDate", ">=", start_utc))
        .where(filter=FieldFilter("entryDate", "<", end_utc))
        .order_by("entryDate", direction=firestore.Query.DESCENDING)
        .stream()
    )

    has_journal_today = False
    numerator = 0.0
    denominator = 0.0

    for snapshot in journal_snapshots:
        has_journal_today = True
        data = snapshot.to_dict() or {}

        user_mood = _normalize_mood(str(data.get("userMood", "Normal")), strict=False)
        numerator += _MOOD_RISK.get(user_mood, 0.0) * _SOURCE_WEIGHT_USER_MOOD
        denominator += _SOURCE_WEIGHT_USER_MOOD

        ai_mood_raw = str(data.get("aiMood", "pending")).strip()
        if ai_mood_raw not in ("pending", ""):
            ai_mood = _normalize_mood(ai_mood_raw, strict=False)
            numerator += _MOOD_RISK.get(ai_mood, 0.0) * _SOURCE_WEIGHT_AI_MOOD
            denominator += _SOURCE_WEIGHT_AI_MOOD

    # Score today's chat sessions
    session_snapshots = (
        db.collection(SESSIONS_COLLECTION)
        .where(filter=FieldFilter("userId", "==", uid))
        .where(filter=FieldFilter("lastMessageAt", ">=", start_utc))
        .where(filter=FieldFilter("lastMessageAt", "<", end_utc))
        .order_by("lastMessageAt", direction=firestore.Query.DESCENDING)
        .stream()
    )

    has_chat_today = False
    for snapshot in session_snapshots:
        data = snapshot.to_dict() or {}
        if str(data.get("status", "active")).lower() != "active":
            continue

        has_chat_today = True
        emotion_counts = data.get("emotionCounts") or {}
        if not isinstance(emotion_counts, dict):
            continue

        for mood, count in emotion_counts.items():
            normalized = _normalize_mood(str(mood), strict=False)
            try:
                count_int = int(count)
            except (TypeError, ValueError):
                continue
            if count_int > 0:
                w = _SOURCE_WEIGHT_CHAT * count_int
                numerator += _MOOD_RISK.get(normalized, 0.0) * w
                denominator += w

    today_score = numerator / denominator if denominator > 0.0 else 0.0

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
        "today_score": today_score,
    }


def _collect_chat_emotion_data(uid: str, days: int = 7) -> list[dict[str, Any]]:
    # gather emotion counts from active chat sessions within the given window for weighted scoring
    db = get_firestore_client()
    now = datetime.now(tz=timezone.utc)
    cutoff = now - timedelta(days=days)

    session_snapshots = (
        db.collection(SESSIONS_COLLECTION)
        .where(filter=FieldFilter("userId", "==", uid))
        .where(filter=FieldFilter("lastMessageAt", ">=", cutoff))
        .order_by("lastMessageAt", direction=firestore.Query.DESCENDING)
        .stream()
    )

    results: list[dict[str, Any]] = []
    for snap in session_snapshots:
        data = snap.to_dict() or {}
        if str(data.get("status", "active")).lower() != "active":
            continue

        last_msg = _parse_timestamp(data.get("lastMessageAt"))
        if last_msg is None:
            continue

        days_ago = max(0.0, (now - last_msg).total_seconds() / 86400)
        emotion_counts = data.get("emotionCounts") or {}
        if not isinstance(emotion_counts, dict):
            continue

        for mood, count in emotion_counts.items():
            normalized = _normalize_mood(str(mood), strict=False)
            try:
                count_int = int(count)
            except (TypeError, ValueError):
                continue
            if count_int > 0:
                results.append({"mood": normalized, "count": count_int, "days_ago": days_ago})

    return results


def _score_from_journal_entries(entries: list, now: datetime) -> tuple[float, float]:
    # shared scoring logic for both 7-day window and fallback entries
    numerator = 0.0
    denominator = 0.0

    for entry in entries:
        # accept both Firestore snapshot dicts and JournalEntryResponse objects
        if isinstance(entry, dict):
            data = entry
            entry_date = _parse_timestamp(data.get("entryDate"))
            user_mood_raw = str(data.get("userMood", "Normal"))
            ai_mood_raw = str(data.get("aiMood", "pending")).strip()
        else:
            entry_date = entry.entry_date
            user_mood_raw = entry.user_mood
            ai_mood_raw = entry.ai_mood.strip() if entry.ai_mood else "pending"

        days_ago = max(0.0, (now - entry_date).total_seconds() / 86400) if entry_date else 0.0
        decay = math.exp(-_DECAY_LAMBDA * days_ago)

        user_mood = _normalize_mood(user_mood_raw, strict=False)
        w_user = _SOURCE_WEIGHT_USER_MOOD * decay
        numerator += _MOOD_RISK.get(user_mood, 0.0) * w_user
        denominator += w_user

        if ai_mood_raw not in ("pending", ""):
            ai_mood = _normalize_mood(ai_mood_raw, strict=False)
            w_ai = _SOURCE_WEIGHT_AI_MOOD * decay
            numerator += _MOOD_RISK.get(ai_mood, 0.0) * w_ai
            denominator += w_ai

    return numerator, denominator


def _compute_weighted_score(uid: str, days: int = 7) -> float:
    # combine journal and chat signals with exponential time decay into a single 0–3 score
    db = get_firestore_client()
    now = datetime.now(tz=timezone.utc)
    cutoff = now - timedelta(days=days)

    journal_snapshots = list(
        db.collection(JOURNALS_COLLECTION)
        .where(filter=FieldFilter("userId", "==", uid))
        .where(filter=FieldFilter("entryDate", ">=", cutoff))
        .order_by("entryDate", direction=firestore.Query.DESCENDING)
        .stream()
    )

    entries = [snap.to_dict() or {} for snap in journal_snapshots]
    numerator, denominator = _score_from_journal_entries(entries, now)

    # add chat emotion counts weighted by source reliability and recency
    for item in _collect_chat_emotion_data(uid, days=days):
        decay = math.exp(-_DECAY_LAMBDA * item["days_ago"])
        w_chat = _SOURCE_WEIGHT_CHAT * decay * item["count"]
        numerator += _MOOD_RISK.get(item["mood"], 0.0) * w_chat
        denominator += w_chat

    # fallback to last 3 entries regardless of date if 7-day window is empty
    if denominator == 0.0:
        fallback_entries = list_journal_entries(uid, limit=3, descending=True)
        numerator, denominator = _score_from_journal_entries(fallback_entries, now)

    return numerator / denominator if denominator > 0.0 else 0.0


def _score_to_status(score: float) -> str:
    # map weighted score to one of three status labels
    if score >= _SCORE_FRAGILE:
        return "Fragile"
    if score >= _SCORE_LOW:
        return "Mainly Low"
    return "Mainly Neutral"


def _score_to_message(status: str) -> str:
    # return a supportive message tailored to the current status label
    if status == "Fragile":
        return "Maybe reach out to someone you trust, you’re not alone"
    if status == "Mainly Low":
        return "Take it easy today and give yourself a few breaks."
    return "You’re doing okay, keep checking in with yourself"


def compute_and_store_mood_stats(uid: str) -> dict[str, Any]:
    # Build and persist mood status focused on dominant emotion and fragile safety state
    today_sources = _collect_today_sources(uid)
    active_sources = list(today_sources.get("active_sources", []))

    today_score = float(today_sources.get("today_score", 0.0))
    has_crisis = today_score >= _CRISIS_SCORE_THRESHOLD
    pulse_recorded_today = bool(today_sources.get("pulse_recorded_today", False))

    score = _compute_weighted_score(uid)
    dominant_emotion = _score_to_status(score)
    emotion_message = _score_to_message(dominant_emotion)

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
    user_ref = db.collection(USERS_COLLECTION).document(uid)
    user_doc = user_ref.get()
    prev_has_crisis = bool(((user_doc.to_dict() or {}).get("moodStats") or {}).get("hasCrisis", False))

    user_ref.set(
        {
            "moodStats": mood_stats,
            "currentStatus": composite_status,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )

    # fire crisis alert only on a false to true transition
    if has_crisis and not prev_has_crisis:
        _maybe_send_crisis_alert(uid, db, mood_stats)

    return mood_stats


def _maybe_send_crisis_alert(uid: str, db, mood_stats: dict[str, Any]) -> None:
    try:
        user_data = (db.collection(USERS_COLLECTION).document(uid).get().to_dict()) or {}
        patient_profile = user_data.get("patientProfile") or {}
        companion = patient_profile.get("companion") or {}
        companion_uid = companion.get("uid")
        companion_status = companion.get("status")
        privacy = patient_profile.get("companionPrivacy") or {}

        # only send if companion is active and mood journal sharing is on
        if not companion_uid:
            return
        if companion_status != "active":
            return
        if not privacy.get("moodJournal", True):
            return

        patient_name = str(user_data.get("fullName") or "Your patient")
        today_key = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        dedupe_key = f"crisis:{uid}:{today_key}"

        send_push(
            uid=companion_uid,
            title="Support needed",
            body=f"{patient_name} may need your support right now",
            notif_type="companion",
            route="mood_status",
            dedupe_key=dedupe_key,
            priority="high",
        )

        # store lastCrisisAlertAt so the cooldown check works next time
        db.collection(USERS_COLLECTION).document(uid).update({
            "moodStats.lastCrisisAlertAt": firestore.SERVER_TIMESTAMP,
        })
    except Exception:
        logger.exception("Failed to send crisis alert for uid=%s", uid)


def _build_mood_stats_api_payload(mood_stats: dict[str, Any], recent_history: list[dict[str, Any]],analysis_pending: bool = False,) -> dict[str, Any]:
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
        "analysis_pending": analysis_pending,
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
    redis = get_redis()
    processing_key = f"{_PROCESSING_KEY_PREFIX}{uid}"

    # Signal to other replicas that analysis is running for this user
    if redis is not None:
        try:
            redis.setex(processing_key, _PROCESSING_TTL, "1")
        except Exception:
            pass

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
    finally:
        if redis is not None:
            try:
                redis.delete(processing_key)
            except Exception:
                pass


def get_mood_stats(uid: str) -> dict[str, Any]:
    # Return fresh synthesis values with recent mood history cards
    analysis_pending = False
    redis = get_redis()
    if redis is not None:
        try:
            analysis_pending = bool(redis.exists(f"{_PROCESSING_KEY_PREFIX}{uid}"))
        except Exception:
            pass

    mood_stats = compute_and_store_mood_stats(uid)
    recent_history = [item.model_dump() for item in list_recent_mood_history(uid)]

    return _build_mood_stats_api_payload(mood_stats, recent_history, analysis_pending)
