"""The contract every FLORA brain implements.

AIService talks only to this interface, so swapping the offline provider for
Claude is a configuration change, not a rewrite of the chat.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum

from app.modules.ai.context import FinancialContext


class ChatRole(str, Enum):
    USER = "user"
    ASSISTANT = "assistant"


@dataclass(frozen=True)
class ChatTurn:
    """One line of the conversation, as it will be replayed to the provider."""

    role: ChatRole
    content: str


@dataclass(frozen=True)
class AIReply:
    """What a provider answers.

    `used_context` says whether the answer leaned on the user's own numbers.
    The app shows it so nobody mistakes a generic sentence for an analysis of
    their statement.
    """

    content: str
    provider: str
    used_context: bool = True
    model: str | None = None
    metadata: dict[str, str] = field(default_factory=dict)


class AIProvider(ABC):
    """A source of FLORA answers."""

    name: str = "unknown"

    @property
    def is_configured(self) -> bool:
        """False when the provider is missing something it needs to run."""
        return True

    @abstractmethod
    async def reply(
        self,
        message: str,
        context: FinancialContext,
        history: list[ChatTurn],
    ) -> AIReply:
        """Answers `message` using `context` and the previous turns."""
        raise NotImplementedError
