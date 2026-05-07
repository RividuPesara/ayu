from datetime import datetime

from pydantic import BaseModel, Field


class TaskCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    date_key: str = Field(min_length=10, max_length=10)
    time: str = Field(min_length=5, max_length=5)


class TaskResponse(BaseModel):
    task_id: str
    user_id: str
    title: str
    date_key: str
    time: str
    is_done: bool
    created_at: datetime | None = None
