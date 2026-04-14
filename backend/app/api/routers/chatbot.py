import asyncio
import functools
import json
import logging
from collections import Counter

logger = logging.getLogger(__name__)

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse

from app.core import chatbot_engine
from app.dependencies.auth import CurrentUser, require_patient_access
from app.schemas.chatbot import (
    ChatResponse,
    CreateSessionRequest,
    MessageResponse,
    SendMessageRequest,
    SessionResponse,
)
from app.services.chatbot_service import (
    create_session,
    get_conversation_history,
    get_crisis_count,
    get_long_term_summary,
    get_session,
    get_unsummarized_sessions,
    get_user_emotion_history,
    list_messages,
    list_sessions,
    mark_session_summarized,
    save_chatbot_message,
    save_patient_message,
    update_long_term_summary,
    update_session_stats,
    write_context_snapshot,
)

router = APIRouter(prefix="/chatbot", tags=["chatbot"])


async def _run_sync(func, *args):
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, functools.partial(func, *args))


# Create a new chat session for the patient
@router.post("/sessions", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
async def create_chat_session(payload: CreateSessionRequest,user: CurrentUser = Depends(require_patient_access),
) -> SessionResponse:
    session = await _run_sync(create_session, user.uid, payload.title)

    # Snapshot the user's current longTermSummary onto the session document so we always know what Ayu knew at the moment this conversation started
    long_term_summary = await _run_sync(get_long_term_summary, user.uid)
    if long_term_summary:
        await _run_sync(write_context_snapshot, session.session_id, long_term_summary)

    return session


# List all sessions belonging to the loggedin patient and backfills any sessions where isSummarized is still False
@router.get("/sessions", response_model=list[SessionResponse])
async def get_chat_sessions(user: CurrentUser = Depends(require_patient_access),) -> list[SessionResponse]:
    sessions, pending, existing_summary = await asyncio.gather(
        _run_sync(list_sessions, user.uid),
        _run_sync(get_unsummarized_sessions, user.uid),
        _run_sync(get_long_term_summary, user.uid),
    )

    if pending:
        # Process each unsummarised session sequentially to avoid spamming Gemini
        for raw in pending:
            sid = raw["session_id"]
            try:
                conv_history, user_emotions, crisis_count = await asyncio.gather(
                    _run_sync(get_conversation_history, sid),
                    _run_sync(get_user_emotion_history, sid),
                    _run_sync(get_crisis_count, sid),
                )
                user_summary = chatbot_engine._generate_user_summary(
                    user_emotions, crisis_count, len(user_emotions)
                )
                updated = await _run_sync(
                    chatbot_engine.generate_long_term_summary,
                    existing_summary,
                    conv_history,
                    user_summary,
                )
                if updated and updated != existing_summary:
                    await _run_sync(update_long_term_summary, user.uid, updated)
                    await _run_sync(mark_session_summarized, sid)
                    # Use the fresh summary as the base for the next pending session
                    existing_summary = updated
                else:
                    # stop trying further sessions to avoid burning more quota
                    break
            except Exception as exc:
                logger.warning("Backfill summary failed for session %s: %s", sid, exc)
                break

    return sessions


# Send a message and receive Ayu's response
@router.post("/sessions/{session_id}/messages", response_model=ChatResponse)
async def send_message(session_id: str,payload: SendMessageRequest,user : CurrentUser = Depends(require_patient_access),
) -> ChatResponse:
    # Validate session ownership and gather all Firestore context concurrently
    _, conversation_history, user_emotions, crisis_count, long_term_summary = (
        await asyncio.gather(
            _run_sync(get_session, session_id, user.uid),
            _run_sync(get_conversation_history, session_id),
            _run_sync(get_user_emotion_history, session_id),
            _run_sync(get_crisis_count, session_id),
            _run_sync(get_long_term_summary, user.uid),
        )
    )
    total_messages = len(user_emotions)

    # Run the full chatbot pipeline
    result = await _run_sync(
        chatbot_engine.process_user_message,
        payload.content,
        conversation_history,
        user_emotions,
        crisis_count,
        total_messages,
        long_term_summary,
    )

    # Build the analysis dict to persist alongside the patient message
    analysis = {
        "emotion_label": result["sentiment"],
        "safety_flag": result["safety_flag"],
        "suicidal_confidence": result["suicidal_confidence"],
        "triggered_by": result["triggered_by"],
    }

    # Persist both the patient message and Ayu's reply
    message_id = await _run_sync(
        save_patient_message, session_id, user.uid, payload.content, analysis
    )
    await _run_sync(save_chatbot_message, session_id, user.uid, result["response"])

    # Update session stats where dominant emotion is the most common across this session
    all_emotions = user_emotions + [result["sentiment"]]
    dominant_emotion = Counter(all_emotions).most_common(1)[0][0] if all_emotions else ""
    new_message_count = total_messages + 1

    await _run_sync(
        update_session_stats, session_id, dominant_emotion, new_message_count
    )

    return ChatResponse(
        response = result["response"],
        sentiment = result["sentiment"],
        safety_flag = result["safety_flag"],
        path_taken = result["path_taken"],
        sources = result.get("sources", []),
        session_id = session_id,
        message_id = message_id,
    )


# Stream Ayu's response token by token using server sent events
@router.post("/sessions/{session_id}/messages/stream")
async def stream_message(
    session_id: str,
    payload : SendMessageRequest,
    user: CurrentUser = Depends(require_patient_access),
):
    # fetches session details, history, and user profile data in parallel
    _, conversation_history, user_emotions, crisis_count, long_term_summary = (
        await asyncio.gather(
            _run_sync(get_session, session_id, user.uid),
            _run_sync(get_conversation_history, session_id),
            _run_sync(get_user_emotion_history, session_id),
            _run_sync(get_crisis_count, session_id),
            _run_sync(get_long_term_summary, user.uid),
        )
    )
    total_messages = len(user_emotions)

    # processes inputs to determine the emotional tone and safety status
    ctx = await _run_sync(
        chatbot_engine.prepare_streaming_context,
        payload.content,
        conversation_history,
        user_emotions,
        crisis_count,
        total_messages,
        long_term_summary,
    )

    analysis = {
        "emotion_label": ctx["sentiment"],
        "safety_flag": ctx["safety_flag"],
        "suicidal_confidence": ctx["suicidal_confidence"],
        "triggered_by": ctx["triggered_by"],
    }

    # logs the user's message to the database before generating a reply
    message_id = await _run_sync(
        save_patient_message, session_id, user.uid, payload.content, analysis,
    )

    # prepares the initial data packet containing sentiment and safety flags
    meta_payload = json.dumps({
        "event": "meta",
        "sentiment": ctx["sentiment"],
        "safety_flag": ctx["safety_flag"],
        "path_taken": ctx["path_taken"],
        "sources": ctx["sources"],
        "session_id" : session_id,
        "message_id": message_id,
    })

    uid = user.uid
    prompt = ctx["prompt"]
    is_crisis = ctx["is_crisis"]
    sentiment = ctx["sentiment"]
    all_emotions = user_emotions + [sentiment]
    dominant_emotion = Counter(all_emotions).most_common(1)[0][0] if all_emotions else ""
    new_msg_count = total_messages + 1

    async def event_generator():
        # sends metadata immediately so the UI can update while the model thinks
        yield f"data: {meta_payload}\n\n"

        full_response_parts: list[str] = []
        loop = asyncio.get_running_loop()

        # starts the background generation task to pipe text tokens to the client
        gen = chatbot_engine.stream_gemini_response(prompt, is_crisis=is_crisis)
        while True:
            chunk = await loop.run_in_executor(None, next, gen, None)
            if chunk is None:
                break
            full_response_parts.append(chunk)
            token_data = json.dumps({"event": "token", "text": chunk})
            yield f"data: {token_data}\n\n"

        full_response = "".join(full_response_parts)

        # stores the complete bot answer and updates session metrics
        await _run_sync(save_chatbot_message, session_id, uid, full_response)
        await _run_sync(update_session_stats, session_id, dominant_emotion, new_msg_count)
        # signals the end of the stream to the frontend
        done_data = json.dumps({"event": "done"})
        yield f"data: {done_data}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


# Fetch the full message history for a session
@router.get("/sessions/{session_id}/messages", response_model=list[MessageResponse])
async def get_session_messages(
    session_id: str,
    user      : CurrentUser = Depends(require_patient_access),
) -> list[MessageResponse]:
    await _run_sync(get_session, session_id, user.uid)
    return await _run_sync(list_messages, session_id)


# End a session and updates longTermSummary by merging old summary with this session's chatwhen the user leaves the chatbot screen
@router.post("/sessions/{session_id}/end", status_code=status.HTTP_200_OK)
async def end_session(session_id: str,user : CurrentUser = Depends(require_patient_access),
) -> dict[str, str]:
    # gathers all session data and the current profile summary in parallel
    _, conversation_history, user_emotions, crisis_count, existing_summary = (
        await asyncio.gather(
            _run_sync(get_session, session_id, user.uid),
            _run_sync(get_conversation_history, session_id),
            _run_sync(get_user_emotion_history, session_id),
            _run_sync(get_crisis_count, session_id),
            _run_sync(get_long_term_summary, user.uid),
        )
    )
    if not conversation_history:
        # skips processing for empty chats but marks them done to prevent retries
        await _run_sync(mark_session_summarized, session_id)
        return {"status": "no_messages"}
    
    # creates a brief snapshot of the user's state during this specific session
    user_summary = chatbot_engine._generate_user_summary(user_emotions, crisis_count, len(user_emotions))
    # uses gemini to integrate the new session details into the master profile
    updated = await _run_sync(
        chatbot_engine.generate_long_term_summary,
        existing_summary,
        conversation_history,
        user_summary,
    )

    # only saves if the summary actually changed to ensure data integrity
    if updated and updated != existing_summary:
        await _run_sync(update_long_term_summary, user.uid, updated)
        await _run_sync(mark_session_summarized, session_id)
        return {"status": "summary_updated"}
    return {"status": "summary_failed"}
