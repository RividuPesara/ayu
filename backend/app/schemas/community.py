from pydantic import BaseModel
from typing import Optional

class CreatePostRequest(BaseModel):
    type: str
    text: Optional[str] = ""
    caption: Optional[str] = ""
    title: Optional[str] = ""
    content: Optional[str] = ""
    imageURL: Optional[str] = ""

class AddCommentRequest(BaseModel):
    text: str