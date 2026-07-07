import logging
import os

logger = logging.getLogger(__name__)

_initialized = False
_enabled = False


def initialize_langfuse() -> None:
    # Wire the configured keys into the process environment once so downstream Langfuse calls pick them up
    global _initialized, _enabled
    if _initialized:
        return
    _initialized = True

    from app.core.config import get_settings
    settings = get_settings()

    if not settings.langfuse_public_key or not settings.langfuse_secret_key:
        logger.info("Langfuse tracing disabled (LANGFUSE_PUBLIC_KEY/LANGFUSE_SECRET_KEY not set)")
        return

    os.environ.setdefault("LANGFUSE_PUBLIC_KEY", settings.langfuse_public_key)
    os.environ.setdefault("LANGFUSE_SECRET_KEY", settings.langfuse_secret_key)
    os.environ.setdefault("LANGFUSE_HOST", settings.langfuse_host)

    _enabled = True
    logger.info("Langfuse tracing enabled (host=%s)", settings.langfuse_host)


def is_langfuse_enabled() -> bool:
    return _enabled


def get_langchain_handler():
    if not _enabled:
        return None
    try:
        from langfuse.langchain import CallbackHandler
        return CallbackHandler()
    except Exception:
        logger.exception("Failed to create Langfuse LangChain callback handler; tracing skipped for this call")
        return None


def get_langfuse_client():
    # Returns the shared Langfuse client for manual spans or None when disabled
    if not _enabled:
        return None
    try:
        from langfuse import get_client
        return get_client()
    except Exception:
        logger.exception("Failed to get Langfuse client; tracing skipped for this call")
        return None


def get_current_trace_id() -> str | None:
    # Reads the trace id of the currently active span if any
    client = get_langfuse_client()
    if client is None:
        return None
    try:
        return client.get_current_trace_id()
    except Exception:
        return None


def record_score(trace_id: str | None,name: str,value: float | str,data_type: str | None = None,
    comment: str | None = None,) -> None:
    # Attach a score to an existing trace
    if not trace_id:
        return
    client = get_langfuse_client()
    if client is None:
        return
    try:
        client.create_score(trace_id=trace_id, name=name, value=value, data_type=data_type, comment=comment)
    except Exception:
        logger.warning("Failed to record Langfuse score '%s' for trace %s", name, trace_id, exc_info=True)
