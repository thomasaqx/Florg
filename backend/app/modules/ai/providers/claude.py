"""FLORA answering through the Claude API.

The key is read from ANTHROPIC_API_KEY on the server and never leaves it: the
app calls POST /ai/chat, this module calls api.anthropic.com. Flutter has no
idea the key exists.

Not reachable until a key is configured -- see `is_configured` and the README
section "Ligando a FLORA no Claude".
"""

import logging
from typing import Any

import httpx

from app.core.config import Settings, get_settings
from app.core.errors import ServiceUnavailableError
from app.modules.ai.context import FinancialContext
from app.modules.ai.prompt import SYSTEM_PROMPT, render_context
from app.modules.ai.providers.base import AIProvider, AIReply, ChatTurn

logger = logging.getLogger(__name__)

_API_URL = "https://api.anthropic.com/v1/messages"
_API_VERSION = "2023-06-01"


class ClaudeProvider(AIProvider):
    """Talks to the Anthropic Messages API."""

    name = "claude"

    def __init__(
        self,
        settings: Settings | None = None,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        self._settings = settings or get_settings()
        # Injectable so the tests can answer without a network.
        self._client = client

    @property
    def is_configured(self) -> bool:
        return self._settings.has_anthropic_key

    async def reply(
        self,
        message: str,
        context: FinancialContext,
        history: list[ChatTurn],
    ) -> AIReply:
        if not self.is_configured:
            raise ServiceUnavailableError(
                "A FLORA não está conectada ao Claude: defina ANTHROPIC_API_KEY no backend."
            )

        payload = self._build_payload(message, context, history)
        data = await self._post(payload)
        return AIReply(
            content=_extract_text(data),
            provider=self.name,
            model=self._settings.anthropic_model,
            used_context=True,
        )

    def _build_payload(
        self, message: str, context: FinancialContext, history: list[ChatTurn]
    ) -> dict[str, Any]:
        # The numbers go in the system prompt, not in the user turn: they are
        # the same for every question and stay out of the conversation the
        # user reads back.
        return {
            "model": self._settings.anthropic_model,
            "max_tokens": self._settings.anthropic_max_tokens,
            "system": f"{SYSTEM_PROMPT}\n\n{render_context(context)}",
            "messages": [
                *({"role": turn.role.value, "content": turn.content} for turn in history),
                {"role": "user", "content": message},
            ],
        }

    async def _post(self, payload: dict[str, Any]) -> dict[str, Any]:
        headers = {
            "x-api-key": self._settings.anthropic_api_key or "",
            "anthropic-version": _API_VERSION,
            "content-type": "application/json",
        }
        timeout = self._settings.anthropic_timeout_seconds

        try:
            if self._client is not None:
                response = await self._client.post(_API_URL, json=payload, headers=headers)
            else:
                async with httpx.AsyncClient(timeout=timeout) as client:
                    response = await client.post(_API_URL, json=payload, headers=headers)
        except httpx.HTTPError as error:
            # The key itself must never reach a log line or an HTTP response.
            logger.warning("Falha ao chamar a API do Claude: %s", type(error).__name__)
            raise ServiceUnavailableError(
                "Não consegui falar com a FLORA agora. Tente de novo em instantes."
            ) from error

        if response.status_code >= 400:
            logger.warning("API do Claude respondeu %s", response.status_code)
            raise ServiceUnavailableError(
                "A FLORA não conseguiu responder agora. Tente de novo em instantes."
            )

        return response.json()


def _extract_text(data: dict[str, Any]) -> str:
    """Joins the text blocks of a Messages API response."""
    blocks = data.get("content") or []
    text = "\n".join(
        block.get("text", "")
        for block in blocks
        if isinstance(block, dict) and block.get("type") == "text"
    ).strip()

    if not text:
        raise ServiceUnavailableError("A FLORA devolveu uma resposta vazia.")
    return text
