import asyncio
import functools

from fastapi import APIRouter, BackgroundTasks, Depends, Query, status

from app.dependencies.auth import CurrentUser, require_patient_access
from app.schemas.journal import (
    DailyPulseRequest,
    DailyPulseUpsertResponse,
    JournalEntriesPageResponse,
    JournalCreateResponse,
    JournalEntryCreateRequest,
    JournalEntryResponse,
    MoodStatsResponse,
)
from app.services.journal_service import (
    create_journal_entry,
    get_journal_entry,
    get_mood_stats,
    list_journal_entries,
    list_journal_entries_page,
    process_journal_entry_background,
    record_daily_pulse,
)

router = APIRouter(prefix="/journal", tags=["journal"])


async def _run_sync(func, *args):
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, functools.partial(func, *args))


@router.post("/pulse", response_model=DailyPulseUpsertResponse, status_code=status.HTTP_200_OK)
async def upsert_daily_pulse(
    payload: DailyPulseRequest,
    user: CurrentUser = Depends(require_patient_access),
) -> DailyPulseUpsertResponse:
    result = await _run_sync(record_daily_pulse, user.uid, payload.mood)
    return DailyPulseUpsertResponse.model_validate(result)


@router.post("/entries", response_model=JournalCreateResponse, status_code=status.HTTP_200_OK)
async def create_entry(
    payload: JournalEntryCreateRequest,
    background_tasks: BackgroundTasks,
    user: CurrentUser = Depends(require_patient_access),
) -> JournalCreateResponse:
    result = await _run_sync(
        create_journal_entry,
        user.uid,
        payload.title,
        payload.content,
        payload.user_mood,
    )
    background_tasks.add_task(
        process_journal_entry_background,
        user.uid,
        result["entry"].entry_id,
    )
    return JournalCreateResponse.model_validate(result)


@router.get("/entries", response_model=list[JournalEntryResponse])
async def get_entries(
    sort: str = Query(default="desc", pattern="^(asc|desc)$"),
    limit: int = Query(default=50, ge=1, le=200),
    user: CurrentUser = Depends(require_patient_access),
) -> list[JournalEntryResponse]:
    descending = sort.lower() != "asc"
    return await _run_sync(list_journal_entries, user.uid, limit, descending)


@router.get("/entries/page", response_model=JournalEntriesPageResponse)
async def get_entries_page(
    sort: str = Query(default="desc", pattern="^(asc|desc)$"),
    limit: int = Query(default=4, ge=1, le=20),
    cursor: str | None = Query(default=None),
    user: CurrentUser = Depends(require_patient_access),
) -> JournalEntriesPageResponse:
    descending = sort.lower() != "asc"
    payload = await _run_sync(
        list_journal_entries_page,
        user.uid,
        limit,
        descending,
        cursor,
        False,
    )
    return JournalEntriesPageResponse.model_validate(payload)


@router.get("/entries/{entry_id}", response_model=JournalEntryResponse)
async def get_entry_detail(
    entry_id: str,
    user: CurrentUser = Depends(require_patient_access),
) -> JournalEntryResponse:
    return await _run_sync(get_journal_entry, user.uid, entry_id)


@router.get("/status", response_model=MoodStatsResponse)
async def get_status(
    user: CurrentUser = Depends(require_patient_access),
) -> MoodStatsResponse:
    status_data = await _run_sync(get_mood_stats, user.uid)
    return MoodStatsResponse.model_validate(status_data)
