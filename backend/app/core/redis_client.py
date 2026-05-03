import logging

import redis

from app.core.config import get_settings

logger = logging.getLogger(__name__)

_redis_client: redis.Redis | None = None
_initialized: bool = False


def get_redis() -> redis.Redis | None:
    # Returns the shared Redis client if available otherwise None
    global _redis_client, _initialized
    if _initialized:
        return _redis_client

    _initialized = True
    settings = get_settings()

    if not settings.redis_url:
        logger.info("REDIS_URL not set — running without Redis degraded mode")
        return None

    try:
        client: redis.Redis = redis.Redis.from_url(
            settings.redis_url,
            decode_responses=True,
            socket_connect_timeout=2,
            socket_timeout=2,
        )
        client.ping()
        _redis_client = client
        logger.info("Redis connected: %s", settings.redis_url)
    except Exception as exc:
        logger.warning("Redis unavailable, running in degraded mode: %s", exc)
        _redis_client = None

    return _redis_client


def initialize_redis() -> None:
    # Call once at startup to create the connection and log status
    get_redis()
