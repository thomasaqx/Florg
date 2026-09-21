import uuid
from datetime import datetime, timezone

from pydantic import BaseModel, Field

from app.modules.ai.context import FinancialContext
from app.modules.ai.providers.base import ChatRole

MAX_MESSAGE_LENGTH = 2000
MAX_HISTORY_ITEMS = 20


class ChatMessage(BaseModel):
    role: ChatRole
    content: str = Field(min_length=1, max_length=MAX_MESSAGE_LENGTH)


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=MAX_MESSAGE_LENGTH)
    # The app replays the conversation; the server keeps no session. Bounded
    # so a client cannot push an unlimited prompt through this endpoint.
    history: list[ChatMessage] = Field(default_factory=list, max_length=MAX_HISTORY_ITEMS)


class ChatResponse(BaseModel):
    id: uuid.UUID = Field(default_factory=uuid.uuid4)
    content: str
    provider: str
    model: str | None = None
    used_context: bool
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class AIStatus(BaseModel):
    """Lets the app say where the answers are coming from."""

    provider: str
    is_live: bool
    suggestions: list[str]


class FinancialContextResponse(BaseModel):
    """The same numbers FLORA reasons over, for the app to show or debug."""

    context: FinancialContext
