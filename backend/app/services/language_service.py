import hashlib
import logging
import re
from deep_translator import GoogleTranslator

from app.core.redis_client import get_redis

logger = logging.getLogger(__name__)

_SINHALA_RE = re.compile(r'[඀-෿]')

# Translations are cached in Redis for 1 hour, shared across all workers,
_TRANSLATION_TTL = 3600


def detect_language(text: str) -> str:
    #Return 'si' if text contains Sinhala characters, else 'en'
    return "si" if _SINHALA_RE.search(text) else "en"


def _cache_key(text: str) -> str:
    # Hash the text so the Redis key is fixed-size and safe regardless of content
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return f"translate:si:en:{digest}"


def _translate_cached(text: str) -> str:
    r = get_redis()
    key = _cache_key(text)

    if r is not None:
        try:
            hit = r.get(key)
            if hit is not None:
                return hit
        except Exception as exc:
            logger.warning("Redis read failed, translating directly: %s", exc)

    translated = GoogleTranslator(source="auto", target="en").translate(text)

    if r is not None:
        try:
            r.set(key, translated, ex=_TRANSLATION_TTL)
        except Exception as exc:
            logger.warning("Redis write failed: %s", exc)

    return translated


def normalize_to_english(text: str) -> tuple[str, str]:
    # Return english_text, detected_lang while Sinhala is translated and english is returned as-i

    lang = detect_language(text)
    if lang == "en":
        return text, lang
    try:
        translated = _translate_cached(text)
        logger.debug("Translated (si→en): %r → %r", text[:80], translated[:80])
        return translated, lang
    except Exception as exc:
        logger.warning("Translation failed: %s — falling back to original", exc)
        return text, lang
