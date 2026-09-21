"""AIService: the only thing the router knows about FLORA.

    router -> AIService -> AIProvider -> (MockAIProvider | ClaudeProvider)

Which provider is chosen comes from configuration, never from the request:
the app cannot ask to be answered by a particular model.
"""

import logging
import uuid
from datetime import date

from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.errors import ServiceUnavailableError
from app.modules.ai.context import FinancialContext, build_financial_context
from app.modules.ai.providers.base import AIProvider, AIReply, ChatTurn
from app.modules.ai.providers.claude import ClaudeProvider
from app.modules.ai.providers.mock import MockAIProvider

logger = logging.getLogger(__name__)

# Enough for FLORA to follow a "e no mês passado?" without resending the whole
# conversation on every request.
MAX_HISTORY_TURNS = 10


def build_provider(settings: Settings | None = None) -> AIProvider:
    """Picks the provider for the configured mode.

    "auto" is what makes a fresh clone work: no key, offline provider, working
    chat. Setting AI_PROVIDER=claude without a key fails here, at boot, rather
    than at the user's first question.
    """
    settings = settings or get_settings()
    mode = settings.ai_provider

    if mode == "mock":
        return MockAIProvider()

    if mode == "claude":
        provider = ClaudeProvider(settings)
        if not provider.is_configured:
            raise RuntimeError(
                "AI_PROVIDER=claude exige ANTHROPIC_API_KEY. "
                "Configure a chave ou use AI_PROVIDER=auto."
            )
        return provider

    if settings.has_anthropic_key:
        return ClaudeProvider(settings)

    logger.info("FLORA sem ANTHROPIC_API_KEY: respondendo pelo provider offline.")
    return MockAIProvider()


class AIService:
    """Assembles the context, asks the provider, degrades instead of failing."""

    def __init__(self, provider: AIProvider, fallback: AIProvider | None = None) -> None:
        self._provider = provider
        # A question answered from the user's own numbers beats an error
        # banner when the external API is down.
        self._fallback = fallback if fallback is not None else MockAIProvider()

    @property
    def provider_name(self) -> str:
        return self._provider.name

    @property
    def is_live(self) -> bool:
        """True when answers come from a real model rather than the offline one."""
        return self._provider.name != MockAIProvider.name

    def context_for(
        self, db: Session, owner_id: uuid.UUID, today: date | None = None
    ) -> FinancialContext:
        return build_financial_context(db, owner_id, today)

    async def answer(
        self,
        db: Session,
        owner_id: uuid.UUID,
        message: str,
        history: list[ChatTurn] | None = None,
        today: date | None = None,
    ) -> AIReply:
        context = self.context_for(db, owner_id, today)
        turns = (history or [])[-MAX_HISTORY_TURNS:]

        try:
            return await self._provider.reply(message, context, turns)
        except ServiceUnavailableError:
            if self._provider is self._fallback:
                raise
            logger.warning(
                "Provider %s indisponível; respondendo pelo offline.", self._provider.name
            )
            reply = await self._fallback.reply(message, context, turns)
            return AIReply(
                content=reply.content,
                provider=reply.provider,
                used_context=reply.used_context,
                model=reply.model,
                metadata={**reply.metadata, "degraded": "true"},
            )


_service: AIService | None = None


def get_ai_service() -> AIService:
    """FastAPI dependency. Built once: the provider holds configuration only."""
    global _service
    if _service is None:
        _service = AIService(build_provider())
    return _service


def reset_ai_service() -> None:
    """Drops the cached service. Used by the tests to swap the provider."""
    global _service
    _service = None
