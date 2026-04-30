import json
import logging
import time
from datetime import datetime, timedelta, timezone
from typing import Any, Iterable

import ollama
from fastapi import HTTPException, status
from firebase_admin import firestore
from google.cloud.firestore_v1 import FieldFilter
from googleapiclient.discovery import build

from app.core.config import get_settings
from app.core.firebase import get_firestore_client
from app.core.redis_client import get_redis
from app.schemas.video import VideoRecommendation

# Redis cache config
_REDIS_YT_TTL = 24 * 3600       # 24 h matches Firestore cache TTL
_REDIS_YT_LOCK_TTL = 30         # prevents thunder herd on simultaneous misses

logger = logging.getLogger(__name__)

USERS_COLLECTION = "users"
SESSIONS_COLLECTION = "sessions"
RECOMMENDATIONS_COLLECTION = "videoRecommendations"
DEFAULT_MAX_PER_QUERY = 2
DEFAULT_QUERY_COUNT = 5
CACHE_TTL_HOURS = 24
INTERACTION_TAG_FIELD = "patientProfile.top_interaction_tags"
RECENTLY_SEEN_FIELD = "patientProfile.recently_seen_video_ids"
RECENTLY_SEEN_LIMIT = 15

RECOMMENDATION_MODES = {
    "normal": "Maintenance & Growth",
    "anxiety": "Quick relief & Grounding",
    "stress": "Quick relief & Grounding",
    "depression": "Gentle encouragement",
    "suicidal": "Grounding & Crisis support",
}

TAG_GROUNDING = "grounding"
TAG_SOMATIC = "somatic"
TAG_AMBIENT = "ambient"

# onboarding tags 
USER_TAG_LABELS = [
    "Calm & peaceful",
    "Educational",
    "Documentary",
    "Science",
    "Songs & music",
]

_TAG_ALIASES = {
    "grounding": TAG_GROUNDING,
    "somatic": TAG_SOMATIC,
    "ambient": TAG_AMBIENT,
    "calm & peaceful": TAG_AMBIENT,
    "songs & music": TAG_AMBIENT,
    "educational": TAG_GROUNDING,
    "documentary": TAG_GROUNDING,
    "science": TAG_GROUNDING,
}


def _parse_timestamp(value: Any) -> datetime | None:
    # timezones consistent across the app
    if value is None:
        return None
    if hasattr(value, "timestamp"):
        try:
            return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value
        except Exception:
            return None
    if isinstance(value, datetime):
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value
    return None


def _normalize_tag(tag: str) -> str:
    # Map user visible tags to internal categories
    raw = str(tag or "").strip()
    if not raw:
        return ""
    lowered = raw.lower()
    direct = _TAG_ALIASES.get(lowered)
    if direct:
        return direct

    return ""


def _normalize_tags(raw_tags: Iterable[Any]) -> list[str]:
    normalized: list[str] = []
    seen: set[str] = set()

    for raw in raw_tags:
        tag = _normalize_tag(str(raw))
        if not tag:
            continue
        if tag in seen:
            continue
        seen.add(tag)
        normalized.append(tag)

    return normalized


def _merge_tags(tags: list[str], interaction_scores: dict[str, int], limit: int = 7) -> list[str]:
    # Mixes user preferences with what they actually clicked on recently
    merged = list(tags)
    # Sort interaction scores to see what the user actually likes best
    for tag, _count in sorted(interaction_scores.items(), key=lambda item: item[1], reverse=True):
        if tag not in merged:
            merged.append(tag)
    if limit > 0:
        return merged[:limit]
    return merged


def _assign_query_tags(queries: list[str], merged_tags: list[str]) -> dict[str, str]:
    # Assign each query a tag by round robin
    normalized = _normalize_tags(merged_tags)
    if not normalized:
        normalized = [TAG_AMBIENT]

    mapping: dict[str, str] = {}
    for index, query in enumerate(queries):
        mapping[query] = normalized[index % len(normalized)]
    return mapping


def _primary_tag_for(video: VideoRecommendation) -> str:
    if video.tags:
        return video.tags[0]
    return TAG_AMBIENT


def _allocate_tag_counts(interaction_scores: dict[str, int],max_items: int,available_tags: list[str],
) -> dict[str, int]:
    # Decides how many videos of each tag to show
    if max_items <= 0:
        return {}

    scores: dict[str, int] = {}
    for tag in available_tags:
        scores[tag] = max(int(interaction_scores.get(tag, 0)), 0)

    total = sum(scores.values())
    # If no history yet just split the count evenly
    if total <= 0:
        base = max_items // max(len(available_tags), 1)
        remainder = max_items - base * len(available_tags)
        allocations = {tag: base for tag in available_tags}
        for tag in available_tags[:remainder]:
            allocations[tag] += 1
        return allocations
    # give more weight to popular tags
    raw = {tag: (scores[tag] / total) * max_items for tag in available_tags}
    allocations = {tag: int(raw[tag]) for tag in available_tags}
    used = sum(allocations.values())
    remainder = max_items - used
    if remainder > 0:
        ranked = sorted(available_tags, key=lambda t: raw[t] - allocations[t], reverse=True)
        for tag in ranked[:remainder]:
            allocations[tag] += 1
    return allocations


def _select_videos_by_tag(
    videos: list[VideoRecommendation],
    interaction_scores: dict[str, int],
    max_items: int,
) -> list[VideoRecommendation]:
    if not videos:
        return []

    buckets: dict[str, list[VideoRecommendation]] = {}
    for video in videos:
        tag = _primary_tag_for(video)
        buckets.setdefault(tag, []).append(video)

    available_tags = list(buckets.keys())
    allocations = _allocate_tag_counts(interaction_scores, max_items, available_tags)

    selected: list[VideoRecommendation] = []
    for tag, count in allocations.items():
        if count <= 0:
            continue
        pool = buckets.get(tag, [])
        selected.extend(pool[:count])
    # Fill in the gaps if we didn't find enough for a specific tag
    if len(selected) < max_items:
        remaining = [v for v in videos if v not in selected]
        selected.extend(remaining[: max_items - len(selected)])

    return selected


def _read_list_field(data: dict[str, Any], *keys: str) -> list[str]:
    for key in keys:
        value = data.get(key)
        if isinstance(value, list):
            return [str(item) for item in value if str(item).strip()]
    return []


def _read_profile_tags(profile: dict[str, Any]) -> list[str]:
    return _read_list_field(
        profile,
        "videoTags",
        "video_tags",
        "interests",
        "storyTags",
        "storyInterests",
    )


def _read_profile_mood(profile: dict[str, Any]) -> tuple[str, str]:
    mood = str(profile.get("moodLabel") or profile.get("currentMood") or "Normal").strip()
    trend = str(profile.get("moodTrend") or profile.get("currentMoodTrend") or "Improving").strip()
    if not mood:
        mood = "Normal"
    if not trend:
        trend = "Improving"
    return mood, trend


def _read_profile_dominant_emotion(profile: dict[str, Any]) -> str:
    raw = profile.get("dominantEmotion") or profile.get("dominant_emotion")
    raw = raw or profile.get("lastEmotion") or profile.get("last_emotion")
    emotion = str(raw or "").strip()
    return emotion


def _read_interaction_scores(profile: dict[str, Any]) -> dict[str, int]:
    # Reads the 'Scoreboard' from the user profile
    raw = profile.get("top_interaction_tags") or profile.get("topInteractionTags")
    if not isinstance(raw, dict):
        return {}
    scores: dict[str, int] = {}
    for key, value in raw.items():
        tag = _normalize_tag(str(key))
        if not tag:
            continue
        try:
            count = int(value)
        except (TypeError, ValueError):
            continue
        if count > 0:
            scores[tag] = count
    return scores


def _read_recently_seen(profile: dict[str, Any]) -> list[str]:
    # Fetches the IDs the user has already seen so we don't repeat them
    raw = profile.get("recently_seen_video_ids")
    if not isinstance(raw, list):
        return []
    return [str(item) for item in raw if str(item).strip()]


def _apply_recently_seen(existing: list[str], new_ids: list[str]) -> list[str]:
    # Updates the FIFO (First-In-First-Out) list of seen videos
    ordered = list(existing)
    for video_id in new_ids:
        if video_id in ordered:
            ordered.remove(video_id)
        ordered.append(video_id)
    if len(ordered) > RECENTLY_SEEN_LIMIT:
        ordered = ordered[-RECENTLY_SEEN_LIMIT:]
    return ordered


def _select_dominant_emotion(uid: str, profile: dict[str, Any]) -> str:
    # Decides the current mood, checking the profile first then the last session
    emotion = _read_profile_dominant_emotion(profile)
    if emotion:
        return emotion

    db = get_firestore_client()
    snapshots = (
        db.collection(SESSIONS_COLLECTION)
        .where(filter=FieldFilter("userId", "==", uid))
        .order_by("lastMessageAt", direction=firestore.Query.DESCENDING)
        .limit(1)
        .stream()
    )

    latest = next(iter(snapshots), None)
    if latest is None:
        return "Normal"

    data = latest.to_dict() or {}
    raw = str(data.get("dominantEmotion") or "").strip()
    return raw or "Normal"


def _recommendation_mode_for(emotion: str) -> str:
    key = str(emotion or "").strip().lower()
    if key in RECOMMENDATION_MODES:
        return RECOMMENDATION_MODES[key]
    return RECOMMENDATION_MODES["normal"]


def get_user_video_context(uid: str) -> tuple[list[str], str, str, dict[str, int], str, list[str]]:
    # Pull user profile inputs needed for recommendations
    db = get_firestore_client()
    snapshot = db.collection(USERS_COLLECTION).document(uid).get()

    if not snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found.",
        )

    data = snapshot.to_dict() or {}
    profile = data.get("patientProfile")
    if not isinstance(profile, dict):
        profile = {}

    mood, trend = _read_profile_mood(profile)
    interaction_scores = _read_interaction_scores(profile)
    dominant_emotion = _select_dominant_emotion(uid, profile)
    recently_seen = _read_recently_seen(profile)

    tags = _normalize_tags(_read_profile_tags(profile) or _read_list_field(data, "videoTags"))
    if not tags and interaction_scores:
        tags = _normalize_tags(list(interaction_scores.keys()))
    if not tags:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User has no video tags saved.",
        )

    return tags, mood, trend, interaction_scores, dominant_emotion, recently_seen


def _build_prompt(
    tags: list[str],
    dominant_emotion: str,
    recommendation_mode: str,
    interaction_scores: dict[str, int],
) -> str:
    joined_tags = ", ".join(tags)
    interactions = ""
    if interaction_scores:
        ranked = sorted(interaction_scores.items(), key=lambda item: item[1], reverse=True)
        interactions = ", ".join([f"{tag} ({count})" for tag, count in ranked])

    return f"""
    You are a mental wellness YouTube video recommendation assistant.
    Your sole purpose is to find videos that are safe, appropriate, and genuinely
    helpful for someone based on their dominant emotional state and preferences.

    Dominant emotion: {dominant_emotion}
    Recommendation mode: {recommendation_mode}
    User preferred video types: {joined_tags}
    Interaction scoreboard (prefer higher counts when safe): {interactions}

    Dominant Emotion Rules

    Suicidal:
        Only recommend extremely gentle and grounding content.
        Must include 5-4-3-2-1 grounding, breathing exercises, encouragement,
        and light motivational support.
        Never suggest anything emotionally intense, heavy, or overwhelming.

    Depression:
        Recommend soft, comforting, and quietly hopeful content.
        Focus on gentle encouragement and soothing tone.

    Anxiety / Stress:
        Recommend quick relief and grounding content.
        Target nervous system regulation and present moment awareness.

    Normal:
        Recommend maintenance and growth oriented content.
        Balanced, uplifting, and steady routines.

    Tag Rules

    The user has selected their preferred video types: {joined_tags}
    These preferences must be reflected across the generated queries.

    Calm & peaceful / Songs & music: ambient, soft music, nature sounds, rain, sleep.
    Educational / Documentary / Science: grounding, explainers, steady learning pace.

    Always blend the mood rules and tag preferences naturally into each query.
    Never generate content that could lead to harmful or triggering results
    for someone in a vulnerable emotional state. When in doubt, choose the gentler option.

    Output

    Generate exactly 5 YouTube search queries based on everything above.
    Each query must be a maximum of 8 words and sound like something a real person would search.
    Return only a JSON array of 5 strings.
    Example: ["query one", "query two", "query three", "query four", "query five"]
    No explanation. No extra text. No markdown. Just the JSON array.
    """


def _generate_queries_with_gemini(prompt: str) -> list[str]:
    from langchain_google_genai import ChatGoogleGenerativeAI
    settings = get_settings()
    if not settings.gemini_api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Gemini API key is not configured.",
        )
    try:
        llm = ChatGoogleGenerativeAI(
            model="gemini-2.5-flash-lite",
            google_api_key=settings.gemini_api_key,
            temperature=0.3,
            max_output_tokens=512,
        )
        response = llm.invoke(prompt)
        raw = getattr(response, "content", None) or getattr(response, "text", None) or ""
        raw = str(raw).strip()
    except Exception as exc:
        logger.warning("Gemini query generation failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Recommendation generator is unavailable. Please try again later.",
        ) from exc

    try:
        return _parse_query_payload(raw)
    except Exception as exc:
        logger.warning("Gemini returned invalid query payload: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Recommendation generator returned an invalid response.",
        ) from exc


def _create_ollama_client() -> ollama.Client:
    settings = get_settings()
    if not settings.ollama_host:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Ollama host is not configured.",
        )

    headers = {}
    if settings.ollama_cf_client_id:
        headers["CF-Access-Client-Id"] = settings.ollama_cf_client_id
    if settings.ollama_cf_client_secret:
        headers["CF-Access-Client-Secret"] = settings.ollama_cf_client_secret

    return ollama.Client(host=settings.ollama_host, headers=headers or None)


def _parse_query_payload(raw: str) -> list[str]:
    if not raw:
        raise ValueError("Empty query payload")

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        start = raw.find("[")
        end = raw.rfind("]")
        if start == -1 or end == -1 or end <= start:
            raise
        parsed = json.loads(raw[start : end + 1])

    if not isinstance(parsed, list):
        raise ValueError("Query payload is not a list")

    queries: list[str] = []
    for item in parsed:
        if not isinstance(item, str):
            continue
        text = item.strip()
        if text:
            queries.append(text)

    return queries


def _generate_queries_with_ollama(
    tags: list[str],
    dominant_emotion: str,
    recommendation_mode: str,
    interaction_scores: dict[str, int],
) -> list[str]:
    # Ask Ollama for YouTube search queries
    settings = get_settings()
    client = _create_ollama_client()
    prompt = _build_prompt(tags, dominant_emotion, recommendation_mode, interaction_scores)

    try:
        response = client.chat(
            model=settings.ollama_model,
            messages=[{"role": "user", "content": prompt}],
        )
    except Exception as exc:
        status_code = getattr(exc, "status_code", None)
        logger.warning("Ollama chat failed (status=%s): %s", status_code, exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Recommendation generator is unavailable. Please try again later.",
        ) from exc

    raw = ""
    if hasattr(response, "message") and hasattr(response.message, "content"):
        raw = response.message.content
    elif isinstance(response, dict):
        raw = str(response.get("message", {}).get("content", ""))

    raw = raw.strip()
    try:
        return _parse_query_payload(raw)
    except Exception as exc:
        logger.warning("Ollama returned invalid query payload: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Recommendation generator returned an invalid response.",
        ) from exc


def generate_search_queries(
    tags: list[str],
    dominant_emotion: str,
    recommendation_mode: str,
    interaction_scores: dict[str, int],
) -> list[str]:
    settings = get_settings()
    prompt = _build_prompt(tags, dominant_emotion, recommendation_mode, interaction_scores)

    if settings.video_provider.lower() == "gemini":
        queries = _generate_queries_with_gemini(prompt)
    else:
        queries = _generate_queries_with_ollama(tags, dominant_emotion, recommendation_mode, interaction_scores)

    if len(queries) < DEFAULT_QUERY_COUNT:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Query generation returned too few queries.",
        )

    return queries[:DEFAULT_QUERY_COUNT]


def _chunk(items: list[str], size: int) -> Iterable[list[str]]:
    for i in range(0, len(items), size):
        yield items[i : i + size]


def _parse_published_at(raw: Any) -> datetime | None:
    if not isinstance(raw, str) or not raw.strip():
        return None
    cleaned = raw.strip().replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(cleaned)
    except ValueError:
        return None


def _fetch_video_stats(youtube, video_ids: list[str]) -> dict[str, dict[str, Any]]:
    # Fetches stats  for a list of IDs
    stats: dict[str, dict[str, Any]] = {}
    if not video_ids:
        return stats

    for batch in _chunk(video_ids, 50):
        try:
            request = youtube.videos().list(
                part="statistics",
                id=",".join(batch),
            )
            response = request.execute()
            for item in response.get("items", []):
                vid = item.get("id")
                if isinstance(vid, str):
                    stats[vid] = item.get("statistics", {}) or {}
        except Exception as exc:
            logger.warning("YouTube stats fetch failed for batch: %s", exc)
            continue

    return stats


def fetch_youtube_videos(
    # Use the YouTube API to get video metadata
    queries: list[str],
    max_per_query: int = DEFAULT_MAX_PER_QUERY,
    query_tag_map: dict[str, str] | None = None,
) -> list[VideoRecommendation]:
    # Query YouTube and attach a tag per query
    settings = get_settings()
    if not settings.youtube_api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="YouTube API key is not configured.",
        )

    try:
        youtube = build("youtube", "v3", developerKey=settings.youtube_api_key)
    except Exception as exc:
        logger.warning("YouTube client init failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="YouTube is unavailable. Please try again later.",
        ) from exc

    videos: list[VideoRecommendation] = []
    seen_ids: set[str] = set()
    raw_items: list[dict[str, Any]] = []

    for query in queries:
        try:
            request = youtube.search().list(
                q=query,
                part="snippet",
                type="video",
                maxResults=max_per_query,
                safeSearch="strict",
                relevanceLanguage="en",
                videoDuration="medium",
            )
            response = request.execute()

            for item in response.get("items", []):
                video_id = item.get("id", {}).get("videoId")
                if not isinstance(video_id, str) or not video_id:
                    continue
                if video_id in seen_ids:
                    continue

                seen_ids.add(video_id)
                snippet = item.get("snippet", {}) or {}

                raw_items.append(
                    {
                        "video_id": video_id,
                        "title": str(snippet.get("title", "")),
                        "channel": str(snippet.get("channelTitle", "")),
                        "thumbnail": str(snippet.get("thumbnails", {}).get("high", {}).get("url", "")),
                        "published_at": snippet.get("publishedAt"),
                        "url": f"https://www.youtube.com/watch?v={video_id}",
                        "query_used": query,
                    }
                )
        except Exception as exc:
            logger.warning("Error fetching videos for query %s: %s", query, exc)
            continue

    stats = _fetch_video_stats(youtube, list(seen_ids))
    # Get view counts in one batch to save API calls
    for item in raw_items:
        video_id = item["video_id"]
        stat = stats.get(video_id, {})
        view_count = stat.get("viewCount")
        try:
            view_count = int(view_count) if view_count is not None else None
        except (TypeError, ValueError):
            view_count = None

        query_tag = TAG_AMBIENT
        if query_tag_map is not None:
            query_tag = query_tag_map.get(item["query_used"], TAG_AMBIENT)
        videos.append(
            VideoRecommendation(
                video_id=video_id,
                title=item["title"],
                channel=item["channel"],
                thumbnail=item["thumbnail"],
                url=item["url"],
                query_used=item["query_used"],
                tags=_normalize_tags([query_tag]),
                published_at=_parse_published_at(item.get("published_at")),
                view_count=view_count,
            )
        )

    return videos


def _map_cached_items(raw_items: Any) -> list[VideoRecommendation]:
    if not isinstance(raw_items, list):
        return []

    items: list[VideoRecommendation] = []
    for raw in raw_items:
        if not isinstance(raw, dict):
            continue

        items.append(
            VideoRecommendation(
                video_id=str(raw.get("video_id", "")),
                title=str(raw.get("title", "")),
                channel=str(raw.get("channel", "")),
                thumbnail=str(raw.get("thumbnail", "")),
                url=str(raw.get("url", "")),
                query_used=str(raw.get("query_used", "")),
                tags=_normalize_tags(raw.get("tags", [])),
                published_at=_parse_timestamp(raw.get("published_at")),
                view_count=raw.get("view_count"),
            )
        )

    return items


def _serialize_recommendations(items: list[VideoRecommendation]) -> list[dict[str, Any]]:
    payload: list[dict[str, Any]] = []
    for item in items:
        payload.append(
            {
                "video_id": item.video_id,
                "title": item.title,
                "channel": item.channel,
                "thumbnail": item.thumbnail,
                "url": item.url,
                "query_used": item.query_used,
                "tags": item.tags,
                "published_at": item.published_at,
                "view_count": item.view_count,
            }
        )
    return payload


def _load_cached(uid: str) -> tuple[list[VideoRecommendation], datetime | None, dict[str, Any]] | None:
    db = get_firestore_client()
    snapshots = (
        db.collection(RECOMMENDATIONS_COLLECTION)
        .where(filter=FieldFilter("userId", "==", uid))
        .order_by("createdAt", direction=firestore.Query.DESCENDING)
        .limit(1)
        .stream()
    )

    doc = next(iter(snapshots), None)
    if doc is None:
        return None

    data = doc.to_dict() or {}
    created_at = _parse_timestamp(data.get("createdAt"))
    items = _map_cached_items(data.get("items"))
    return items, created_at, data


def _is_cache_valid(created_at: datetime | None) -> bool:
    if created_at is None:
        return False
    now = datetime.now(timezone.utc)
    return now - created_at <= timedelta(hours=CACHE_TTL_HOURS)


def _redis_yt_key(uid: str) -> str:
    return f"ayu:youtube:{uid}"


def _redis_yt_lock_key(uid: str) -> str:
    return f"ayu:youtube:lock:{uid}"


def _serialize_for_redis(items: list[VideoRecommendation]) -> str:
    payload = []
    for item in items:
        payload.append({
            "video_id": item.video_id,
            "title": item.title,
            "channel": item.channel,
            "thumbnail": item.thumbnail,
            "url": item.url,
            "query_used": item.query_used,
            "tags": item.tags,
            "published_at": item.published_at.isoformat() if item.published_at else None,
            "view_count": item.view_count,
        })
    return json.dumps(payload)


def _load_from_redis(uid: str) -> list[VideoRecommendation] | None:
    redis = get_redis()
    if redis is None:
        return None
    try:
        raw = redis.get(_redis_yt_key(uid))
        if not raw:
            return None
        items = _map_cached_items(json.loads(raw))
        return items if items else None
    except Exception:
        return None


def _save_to_redis(uid: str, items: list[VideoRecommendation]) -> None:
    redis = get_redis()
    if redis is None:
        return
    try:
        redis.setex(_redis_yt_key(uid), _REDIS_YT_TTL, _serialize_for_redis(items))
    except Exception:
        pass


def get_video_recommendations(uid: str, refresh: bool = False, max_per_query: int = DEFAULT_MAX_PER_QUERY,
) -> tuple[list[VideoRecommendation], dict[str, Any]]:
    # Checks Redis then Firestore then YouTube so all replicas share one result pool
    tags, mood, trend, interaction_scores, dominant_emotion, recently_seen = get_user_video_context(uid)
    recommendation_mode = _recommendation_mode_for(dominant_emotion)
    seen_ids = set(recently_seen)

    def _make_meta(cached: bool, generated_at: Any, data: dict[str, Any]) -> dict[str, Any]:
        return {
            "cached": cached,
            "generated_at": generated_at,
            "tags": _normalize_tags(data.get("tags", []) or tags),
            "mood": str(data.get("mood") or dominant_emotion),
            "mood_trend": str(data.get("moodTrend") or trend),
            "dominant_emotion": str(data.get("dominantEmotion") or dominant_emotion),
            "recommendation_mode": str(data.get("recommendationMode") or recommendation_mode),
        }

    # Redis global cache which is shared across all replicas
    if not refresh:
        redis_items = _load_from_redis(uid)
        if redis_items:
            filtered = [item for item in redis_items if item.video_id not in seen_ids]
            if filtered:
                try:
                    update_recently_seen(uid, [item.video_id for item in filtered])
                except Exception as exc:
                    logger.warning("Failed to update recently seen ids: %s", exc)
                return filtered, _make_meta(True, datetime.now(timezone.utc), {
                    "tags": tags, "mood": dominant_emotion, "moodTrend": trend,
                    "dominantEmotion": dominant_emotion, "recommendationMode": recommendation_mode,
                })

    # firestore per user cache and populate Redis on hit
    firestore_cached = _load_cached(uid)
    if not refresh and firestore_cached is not None:
        items, created_at, data = firestore_cached
        if items and _is_cache_valid(created_at):
            filtered = [item for item in items if item.video_id not in seen_ids]
            if filtered:
                _save_to_redis(uid, filtered)
                try:
                    update_recently_seen(uid, [item.video_id for item in filtered])
                except Exception as exc:
                    logger.warning("Failed to update recently seen ids: %s", exc)
                return filtered, _make_meta(True, created_at, data)

    # Fetch from Ollama and YouTube use a per uid Redis lock to prevent thunderherd
    redis = get_redis()
    lock_acquired = False
    if redis is not None:
        try:
            lock_acquired = bool(redis.set(_redis_yt_lock_key(uid), "1", nx=True, ex=_REDIS_YT_LOCK_TTL))
            if not lock_acquired:
                # Another replica is already fetching so wait briefly and try Redis again
                time.sleep(3)
                redis_items = _load_from_redis(uid)
                if redis_items:
                    filtered = [item for item in redis_items if item.video_id not in seen_ids]
                    if filtered:
                        return filtered, _make_meta(True, datetime.now(timezone.utc), {
                            "tags": tags, "mood": dominant_emotion, "moodTrend": trend,
                            "dominantEmotion": dominant_emotion, "recommendationMode": recommendation_mode,
                        })
        except Exception:
            pass

    merged_tags = _merge_tags(tags, interaction_scores)

    try:
        try:
            queries = generate_search_queries(merged_tags, dominant_emotion, recommendation_mode, interaction_scores)
        except HTTPException as exc:
            stale = firestore_cached or _load_cached(uid)
            if stale is not None:
                items, created_at, data = stale
                if items:
                    logger.info("Serving cached recommendations after generator failure.")
                    return items, _make_meta(True, created_at, data)
            raise exc

        query_tag_map = _assign_query_tags(queries, merged_tags)

        try:
            items = fetch_youtube_videos(queries, max_per_query=max_per_query, query_tag_map=query_tag_map)
        except HTTPException as exc:
            stale = firestore_cached or _load_cached(uid)
            if stale is not None:
                items, created_at, data = stale
                if items:
                    logger.info("Serving cached recommendations after YouTube failure.")
                    return items, _make_meta(True, created_at, data)
            raise exc

        candidates = [item for item in items if item.video_id not in seen_ids]
        if not candidates:
            candidates = items

        max_items = max_per_query * DEFAULT_QUERY_COUNT
        selected = _select_videos_by_tag(candidates, interaction_scores, max_items) or candidates

        try:
            update_recently_seen(uid, [item.video_id for item in selected])
        except Exception as exc:
            logger.warning("Failed to update recently seen ids: %s", exc)

        # Persist to Redis (global, instant for next replica) and Firestore (durable)
        _save_to_redis(uid, selected)

        db = get_firestore_client()
        db.collection(RECOMMENDATIONS_COLLECTION).document().set({
            "userId": uid,
            "createdAt": firestore.SERVER_TIMESTAMP,
            "tags": tags,
            "mood": dominant_emotion,
            "moodTrend": trend,
            "dominantEmotion": dominant_emotion,
            "recommendationMode": recommendation_mode,
            "queries": queries,
            "items": _serialize_recommendations(selected),
        })

        return selected, _make_meta(False, datetime.now(timezone.utc), {
            "tags": tags, "mood": dominant_emotion, "moodTrend": trend,
            "dominantEmotion": dominant_emotion, "recommendationMode": recommendation_mode,
        })
    finally:
        if lock_acquired and redis is not None:
            try:
                redis.delete(_redis_yt_lock_key(uid))
            except Exception:
                pass


def record_video_interaction(uid: str, tags: Iterable[str]) -> dict[str, int]:
    # Update the interaction scoreboard totals
    normalized = _normalize_tags(tags)
    if not normalized:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No tags supplied for tracking.",
        )

    db = get_firestore_client()
    doc_ref = db.collection(USERS_COLLECTION).document(uid)

    @firestore.transactional
    def _apply(transaction: firestore.Transaction) -> dict[str, int]:
        snapshot = doc_ref.get(transaction=transaction)
        profile: dict[str, Any] = {}
        if snapshot.exists:
            raw = snapshot.to_dict() or {}
            profile = raw.get("patientProfile") if isinstance(raw.get("patientProfile"), dict) else {}

        current = _read_interaction_scores(profile)
        for tag in normalized:
            current[tag] = int(current.get(tag, 0)) + 1

        transaction.update(doc_ref, {INTERACTION_TAG_FIELD: current})
        return current

    return _apply(db.transaction())


def update_recently_seen(uid: str, new_ids: list[str]) -> list[str]:
    # Keep a FIFO list of recently served video ids
    if not new_ids:
        return []

    db = get_firestore_client()
    doc_ref = db.collection(USERS_COLLECTION).document(uid)

    @firestore.transactional
    def _apply(transaction: firestore.Transaction) -> list[str]:
        snapshot = doc_ref.get(transaction=transaction)
        profile: dict[str, Any] = {}
        if snapshot.exists:
            raw = snapshot.to_dict() or {}
            profile = raw.get("patientProfile") if isinstance(raw.get("patientProfile"), dict) else {}

        current = _read_recently_seen(profile)
        updated = _apply_recently_seen(current, new_ids)
        transaction.update(doc_ref, {RECENTLY_SEEN_FIELD: updated})
        return updated

    return _apply(db.transaction())
