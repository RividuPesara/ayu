from datetime import datetime

from pydantic import BaseModel, Field


class DailyPulseRequest(BaseModel):
    # Raw daily mood anchor selected by the user
    mood: str = Field(min_length=2, max_length=40)


class DailyPulseResponse(BaseModel):
    pulse_id: str
    mood: str
    timestamp: datetime | None = None


class JournalEntryCreateRequest(BaseModel):
    # Manual reflective journal content written by the user.
    title: str = Field(min_length=1, max_length=200)
    content: str = Field(min_length=1, max_length=5000)
    user_mood: str = Field(min_length=2, max_length=40)


class JournalEntryResponse(BaseModel):
    # Journal document persisted in Firestore.
    entry_id: str
    user_id: str
    title: str
    content: str = ""
    user_mood: str
    ai_mood: str = "pending"
    is_mismatch: bool = False
    safety_flag: str = "non_crisis"
    entry_date: datetime | None = None


class MoodHistoryItem(BaseModel):
    month: str
    day: str
    title: str
    mood: str


class MoodStatsResponse(BaseModel):
    # Aggregated mood status with dominant emotion and safety signal.
    current_status: str = "Mainly Neutral"
    composite_status: str = "Mainly Neutral"
    status_label: str = ""
    dominant_emotion: str = "Mainly Neutral"
    emotion_message: str = ""
    active_days_count: int = 0
    journal_streak: int = 0
    last_active_date_key: str = ""
    pulse_recorded_today: bool = False
    has_crisis: bool = False
    recent_history: list[MoodHistoryItem] = Field(default_factory=list)
    # True while a journal entry's background sentiment analysis is still running
    analysis_pending: bool = False


class DailyPulseUpsertResponse(BaseModel):
    pulse: DailyPulseResponse
    mood_stats: MoodStatsResponse


class JournalCreateResponse(BaseModel):
    entry: JournalEntryResponse
    queued: bool = True
    active_days_count: int = 0
    journal_streak: int = 0
    day_incremented: bool = False
    last_active_date_key: str = ""


class JournalEntriesPageResponse(BaseModel):
    entries: list[JournalEntryResponse] = Field(default_factory=list)
    next_cursor: str | None = None
    has_more: bool = False
