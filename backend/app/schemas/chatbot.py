from datetime import datetime
from pydantic import BaseModel, Field


class CreateSessionRequest(BaseModel):
    # Title chat session
    title: str = Field(min_length=1, max_length=200)


class SessionResponse(BaseModel):
    # chat session belonging to a patient
    session_id: str
    user_id: str
    title: str
    status: str = "active"
    dominant_emotion: str = ""
    message_count: int = 0
    created_at: datetime | None = None
    last_message_at: datetime | None = None


class SendMessageRequest(BaseModel):
    # The patient's message content
    content: str = Field(min_length=1, max_length=5000)


class MessageAnalysis(BaseModel):
    # Sentiment and safety analysis attached to a patient message
    emotion_label: str
    safety_flag: str
    suicidal_confidence: float
    triggered_by: str


class MessageResponse(BaseModel):
    # A single message document from Firestore
    message_id: str
    session_id: str
    user_id: str
    role: str
    content: str
    timestamp: datetime | None = None
    analysis: MessageAnalysis | None = None


class ChatResponse(BaseModel):
    # Full response returned after sending a message
    immediate_response: str | None = None
    response: str
    sentiment: str
    safety_flag: str
    path_taken: str
    sources: list[str] = []
    session_id: str
    message_id: str
