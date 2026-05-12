import asyncio
import functools

from fastapi import APIRouter, Depends, status

from app.dependencies.auth import CurrentUser, require_patient_access, require_patient_or_companion_access
from app.schemas.task import TaskCreateRequest, TaskResponse
from app.services.task_service import create_task, delete_task, list_tasks, toggle_task
from app.services.companion_service import resolve_and_check_privacy

router = APIRouter(prefix="/tasks", tags=["tasks"])


async def _run_sync(func, *args):
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, functools.partial(func, *args))


@router.post("", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
async def add_task(payload: TaskCreateRequest,user: CurrentUser = Depends(require_patient_access),
) -> TaskResponse:
    # Create a new task for the patient
    return await _run_sync(create_task, user.uid, payload.title, payload.date_key, payload.time)


@router.get("", response_model=list[TaskResponse])
async def get_tasks(date: str, user: CurrentUser = Depends(require_patient_or_companion_access),
) -> list[TaskResponse]:
    patient_uid = user.uid
    if user.role == "companion":
        patient_uid = await _run_sync(resolve_and_check_privacy, user.uid, "todo_list")
    return await _run_sync(list_tasks, patient_uid, date)


@router.patch("/{task_id}/toggle", response_model=TaskResponse)
async def toggle_task_done(task_id: str,user: CurrentUser = Depends(require_patient_access),
) -> TaskResponse:
    # Flip the isDone state of a task
    return await _run_sync(toggle_task, user.uid, task_id)


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_task(task_id: str,user: CurrentUser = Depends(require_patient_access),
) -> None:
    # Delete a task
    await _run_sync(delete_task, user.uid, task_id)
