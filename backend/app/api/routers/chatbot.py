import asyncio
import functools
import json
import logging

logger = logging.getLogger(__name__)

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
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
    archive_all_sessions,
    archive_session,
    create_session,
    get_conversation_history,
    get_long_term_summary,
    get_session,
    get_session_aggregates,
    get_unsummarized_sessions,
    invalidate_conversation_history,
    list_messages,
    list_sessions,
    mark_session_summarized,
    save_chatbot_message,
    save_patient_message,
    update_long_term_summary,
    update_session_stats,
    write_context_snapshot,
)
from app.services.journal_service import compute_and_store_mood_stats

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
                conv_history, aggregates = await asyncio.gather(
                    _run_sync(get_conversation_history, sid),
                    _run_sync(get_session_aggregates, sid),
                )
                if int(aggregates["patient_message_count"]) < 3:
                    await _run_sync(mark_session_summarized, sid)
                    continue
                user_summary = chatbot_engine._generate_user_summary(
                    aggregates["emotion_counts"],
                    int(aggregates["crisis_count"]),
                    int(aggregates["patient_message_count"]),
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


@router.post("/sessions/{session_id}/archive", status_code=status.HTTP_200_OK)
async def archive_chat_session(
    session_id: str,
    user: CurrentUser = Depends(require_patient_access),
) -> dict[str, str]:
    await _run_sync(get_session, session_id, user.uid)
    await _run_sync(archive_session, session_id)
    return {"status": "archived"}


@router.post("/sessions/archive-all", status_code=status.HTTP_200_OK)
async def archive_all_chat_sessions(
    user: CurrentUser = Depends(require_patient_access),
) -> dict[str, int | str]:
    count = await _run_sync(archive_all_sessions, user.uid)
    return {"status": "archived", "count": count}


# Send a message and receive Ayu's response
@router.post("/sessions/{session_id}/messages", response_model=ChatResponse)
async def send_message(session_id: str, payload: SendMessageRequest, background_tasks: BackgroundTasks, user: CurrentUser = Depends(require_patient_access),
) -> ChatResponse:
    # Validate session ownership and gather all Firestore context concurrently
    _, conversation_history, aggregates, long_term_summary = (
        await asyncio.gather(
            _run_sync(get_session, session_id, user.uid),
            _run_sync(get_conversation_history, session_id),
            _run_sync(get_session_aggregates, session_id),
            _run_sync(get_long_term_summary, user.uid),
        )
    )
    emotion_counts = dict(aggregates.get("emotion_counts", {}))
    crisis_count = int(aggregates.get("crisis_count", 0))
    total_messages = int(aggregates.get("patient_message_count", 0))

    # Run the full chatbot pipeline
    result = await _run_sync(
        chatbot_engine.process_user_message,
        payload.content,
        conversation_history,
        emotion_counts,
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

    # both message saves must complete before returning so the next request sees full history
    message_id = await _run_sync(
        save_patient_message, session_id, user.uid, payload.content, analysis
    )
    await _run_sync(save_chatbot_message, session_id, user.uid, result["response"])
    # stats update and cache invalidation don't affect the next request's correctness
    background_tasks.add_task(_run_sync, update_session_stats, session_id, result["sentiment"], result["safety_flag"])
    background_tasks.add_task(_run_sync, invalidate_conversation_history, session_id)

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
    _, conversation_history, aggregates, long_term_summary = (
        await asyncio.gather(
            _run_sync(get_session, session_id, user.uid),
            _run_sync(get_conversation_history, session_id),
            _run_sync(get_session_aggregates, session_id),
            _run_sync(get_long_term_summary, user.uid),
        )
    )
    emotion_counts = dict(aggregates.get("emotion_counts", {}))
    crisis_count = int(aggregates.get("crisis_count", 0))
    total_messages = int(aggregates.get("patient_message_count", 0))

    # processes inputs to determine the emotional tone and safety status
    ctx = await _run_sync(
        chatbot_engine.prepare_streaming_context,
        payload.content,
        conversation_history,
        emotion_counts,
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

        # stores the complete bot answer and updates session metrics and remove the history cache
        await _run_sync(save_chatbot_message, session_id, uid, full_response)
        await _run_sync(update_session_stats, session_id, ctx["sentiment"], ctx["safety_flag"])
        await _run_sync(invalidate_conversation_history, session_id)
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
    limit: int = Query(default=50, ge=1, le=200),
    start_after: str | None = Query(default=None),
    user      : CurrentUser = Depends(require_patient_access),
) -> list[MessageResponse]:
    await _run_sync(get_session, session_id, user.uid)
    return await _run_sync(list_messages, session_id, limit, start_after)


# End a session and updates longTermSummary by merging old summary with this session's chatwhen the user leaves the chatbot screen
@router.post("/sessions/{session_id}/end", status_code=status.HTTP_200_OK)
async def end_session(session_id: str,user : CurrentUser = Depends(require_patient_access),
) -> dict[str, str]:
    # gathers all session data and the current profile summary in parallel
    _, conversation_history, aggregates, existing_summary = (
        await asyncio.gather(
            _run_sync(get_session, session_id, user.uid),
            _run_sync(get_conversation_history, session_id),
            _run_sync(get_session_aggregates, session_id),
            _run_sync(get_long_term_summary, user.uid),
        )
    )
    if not conversation_history:
        # skips processing for empty chats but marks them done to prevent retries
        await _run_sync(mark_session_summarized, session_id)
        # refresh mood status so chat data is reflected even for empty sessions
        await _run_sync(compute_and_store_mood_stats, user.uid)
        return {"status": "no_messages"}

    _MIN_MESSAGES_FOR_SUMMARY = 3
    if int(aggregates["patient_message_count"]) < _MIN_MESSAGES_FOR_SUMMARY:
        await _run_sync(mark_session_summarized, session_id)
        # refresh mood status to pick up any emotion signals from the short session
        await _run_sync(compute_and_store_mood_stats, user.uid)
        return {"status": "skipped_too_short"}

    # creates a brief snapshot of the user's state during this specific session
    user_summary = chatbot_engine._generate_user_summary(
        aggregates["emotion_counts"],
        int(aggregates["crisis_count"]),
        int(aggregates["patient_message_count"]),
    )
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
        # refresh mood status now that chat emotion data from this session is finalised
        await _run_sync(compute_and_store_mood_stats, user.uid)
        return {"status": "summary_updated"}

    # still refresh mood status even if summary did not change
    await _run_sync(compute_and_store_mood_stats, user.uid)
    return {"status": "summary_failed"}
