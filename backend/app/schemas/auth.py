from pydantic import BaseModel

class AuthStatusResponse(BaseModel):
  #auth status response for the current log in user
  uid: str
  role: str
  email: str | None = None
  full_name: str | None = None