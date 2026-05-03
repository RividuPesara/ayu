import base64
import json
import time
import urllib.error
import urllib.request
from datetime import datetime
from typing import Any

from fastapi import HTTPException, status

from app.core.config import get_settings
from app.core.redis_client import get_redis

# Redis keys
_REDIS_TOKEN_KEY = "ayu:zoom:token"
_REDIS_LOCK_KEY = "ayu:zoom:refresh_lock"
_LOCK_TTL = 30  # long enough to fetch a token, short enough to auto expire on crash

# fallback used when Redis is unavailable
_LOCAL_CACHE: dict[str, Any] = {"access_token": None, "expires_at": 0.0}


def _require_zoom_settings() -> tuple[str, str, str]:
    settings = get_settings()
    account_id = (settings.zoom_account_id or "").strip()
    client_id = (settings.zoom_client_id or "").strip()
    client_secret = (settings.zoom_client_secret or "").strip()

    if not account_id or not client_id or not client_secret:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Zoom configuration is missing.",
        )

    return account_id, client_id, client_secret

# Handle all the talking to the Zoom API
def _zoom_request_json(method: str,url: str,*,headers: dict[str, str] | None = None,payload: dict[str, Any] | None = None,
    timeout: int = 20,
    allow_not_found: bool = False,
) -> dict[str, Any]:
    body = None
    request_headers = headers.copy() if headers else {}

    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        request_headers.setdefault("Content-Type", "application/json")

    request = urllib.request.Request(url, data=body, headers=request_headers, method=method)

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        if allow_not_found and exc.code == 404:
            return {}
        error_body = exc.read().decode("utf-8")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Zoom API error: {error_body or exc.reason}",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to reach Zoom API.",
        ) from exc

    try:
        return json.loads(raw) if raw else {}
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Zoom API returned invalid JSON.",
        ) from exc

# Encodes Client ID and Secret into the format Zoom's login expects
def _build_basic_auth(client_id: str, client_secret: str) -> str:
    token = f"{client_id}:{client_secret}".encode("utf-8")
    return base64.b64encode(token).decode("utf-8")


def _fetch_new_zoom_token() -> tuple[str, int]:
    # Call the Zoom OAuth endpoint and return (access_token, expires_in_seconds)
    account_id, client_id, client_secret = _require_zoom_settings()
    basic = _build_basic_auth(client_id, client_secret)
    url = f"https://zoom.us/oauth/token?grant_type=account_credentials&account_id={account_id}"

    response = _zoom_request_json(
        "POST",
        url,
        headers={"Authorization": f"Basic {basic}"},
    )

    token = response.get("access_token")
    if not isinstance(token, str) or not token:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Zoom did not return an access token.",
        )

    try:
        expires_in = int(response.get("expires_in") or 0)
    except Exception:
        expires_in = 0

    return token, expires_in


def get_zoom_access_token() -> str:
    # Gets a valid Zoom access token by using Redis caching and locking to avoid duplicate refreshes, with a simple in memory fallback if Redis isn’t available
    redis = get_redis()

    if redis is not None:
        try:
            cached = redis.get(_REDIS_TOKEN_KEY)
            if cached:
                return cached

            # Acquire distributed lock here NX means "only set if not exists"
            acquired = redis.set(_REDIS_LOCK_KEY, "1", nx=True, ex=_LOCK_TTL)
            if not acquired:
                # Another replica is mid refresh if so wait briefly and recheck
                time.sleep(2)
                cached = redis.get(_REDIS_TOKEN_KEY)
                if cached:
                    return cached

            try:
                token, expires_in = _fetch_new_zoom_token()
                ttl = max(60, expires_in - 60)
                redis.setex(_REDIS_TOKEN_KEY, ttl, token)
                return token
            finally:
                if acquired:
                    try:
                        redis.delete(_REDIS_LOCK_KEY)
                    except Exception:
                        pass
        except HTTPException:
            raise
        except Exception:
            pass

    now = time.time()
    cached_token = _LOCAL_CACHE.get("access_token")
    expires_at = float(_LOCAL_CACHE.get("expires_at") or 0.0)
    if cached_token and expires_at - 60 > now:
        return str(cached_token)

    token, expires_in = _fetch_new_zoom_token()
    _LOCAL_CACHE["access_token"] = token
    _LOCAL_CACHE["expires_at"] = now + max(0, expires_in)
    return token

# The main function to schedule a new Zoom call for a specific doctor
def create_zoom_meeting( *, user_id: str,topic: str,start_time: datetime,duration_minutes: int,timezone_name: str,
) -> dict[str, Any]:
    access_token = get_zoom_access_token()

    payload = {
        "topic": topic,
        "type": 2,
        "start_time": start_time.isoformat(),
        "duration": max(1, duration_minutes),
        "timezone": timezone_name,
        "settings": {
            "join_before_host": False,
            "waiting_room": True, # keeps patients in the waiting room
        },
    }
    # Calls the meeting endpoint using the doctor's unique User ID
    response = _zoom_request_json("POST",f"https://api.zoom.us/v2/users/{user_id}/meetings",
    headers={"Authorization": f"Bearer {access_token}"},
        payload=payload,
    )

    if "id" not in response:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Zoom did not return meeting details.",
        )

    return response

# Automatically finds a doctor's Zoom ID using just their email
def get_zoom_user_id_by_email(email: str) -> str | None:
    normalized = email.strip()
    if not normalized:
        return None

    access_token = get_zoom_access_token()
    response = _zoom_request_json(
        "GET",
        f"https://api.zoom.us/v2/users/{normalized}",
        headers={"Authorization": f"Bearer {access_token}"},
        allow_not_found=True,
    )
    # Grabs the 'id' field which we then save to Firestore
    user_id = response.get("id") if isinstance(response, dict) else None
    if isinstance(user_id, str) and user_id.strip():
        return user_id

    return None
