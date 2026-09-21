"""FLORA: the context she reads, what she answers, and where the key lives."""

import asyncio
import uuid
from datetime import date
from decimal import Decimal

import httpx
import pytest

from app.core.config import Settings
from app.core.errors import ServiceUnavailableError
from app.modules.ai.context import build_financial_context
from app.modules.ai.intents import Intent, detect_intent
from app.modules.ai.prompt import render_context
from app.modules.ai.providers.base import AIProvider, AIReply, ChatRole, ChatTurn
from app.modules.ai.providers.claude import ClaudeProvider
from app.modules.ai.providers.mock import MockAIProvider
from app.modules.ai.service import AIService, build_provider, get_ai_service
from app.main import app


def _settings(**overrides) -> Settings:
    base = {
        "database_url": "sqlite://",
        "secret_key": "chave-de-teste-com-mais-de-32-bytes-para-o-pytest",
    }
    base.update(overrides)
    return Settings(**base)


def _owner_id(client, auth_headers):
    return uuid.UUID(client.get("/auth/me", headers=auth_headers).json()["id"])


def _expense(client, auth_headers, account, description, amount, occurred_at):
    return client.post(
        "/transactions",
        headers=auth_headers,
        json={
            "account_id": account["id"],
            "description": description,
            "amount": amount,
            "type": "expense",
            "occurred_at": occurred_at,
        },
    )


def _income(client, auth_headers, account, amount, occurred_at):
    return client.post(
        "/transactions",
        headers=auth_headers,
        json={
            "account_id": account["id"],
            "description": "Salario",
            "amount": amount,
            "type": "income",
            "occurred_at": occurred_at,
        },
    )


@pytest.fixture
def statement(client, auth_headers, account):
    """Two months of movement, so the comparisons have a base."""
    _income(client, auth_headers, account, "9250.00", "2026-04-05")
    _expense(client, auth_headers, account, "Supermercado", "1240.00", "2026-04-08")
    _expense(client, auth_headers, account, "Uber", "410.00", "2026-04-12")
    _expense(client, auth_headers, account, "Netflix", "55.90", "2026-04-15")
    _expense(client, auth_headers, account, "Netflix", "55.90", "2026-03-15")
    _expense(client, auth_headers, account, "Supermercado de marco", "620.00", "2026-03-08")
    return account


@pytest.fixture
def statement_this_month(client, auth_headers, account):
    """The same statement, dated in the running month.

    The endpoints read date.today(); pinning them to a fixed month would make
    every assertion here expire.
    """
    today = date.today()
    day = today.replace(day=min(today.day, 28)).isoformat()
    _income(client, auth_headers, account, "9250.00", day)
    _expense(client, auth_headers, account, "Supermercado", "1240.00", day)
    _expense(client, auth_headers, account, "Uber", "410.00", day)
    return account


# --- context ---------------------------------------------------------------


def test_context_reflects_the_month(client, auth_headers, db_session, statement):
    context = build_financial_context(
        db_session, _owner_id(client, auth_headers), today=date(2026, 4, 20)
    )

    assert context.month_income == Decimal("9250.00")
    assert context.month_expenses == Decimal("1705.90")
    assert context.month_net == Decimal("7544.10")
    assert context.previous_month_expenses == Decimal("675.90")
    assert context.month_label == "abril de 2026"


def test_context_ranks_categories_and_compares_with_last_month(
    client, auth_headers, db_session, statement
):
    context = build_financial_context(
        db_session, _owner_id(client, auth_headers), today=date(2026, 4, 20)
    )

    top = context.spending_by_category[0]
    assert top.name == "Alimentação"
    assert top.total == Decimal("1240.00")
    assert top.previous_month_total == Decimal("620.00")
    assert top.change_percent == pytest.approx(100.0)


def test_context_finds_the_repeated_charge(client, auth_headers, db_session, statement):
    context = build_financial_context(
        db_session, _owner_id(client, auth_headers), today=date(2026, 4, 20)
    )

    descriptions = [item.description for item in context.recurring_expenses]
    assert descriptions == ["Netflix"]
    assert context.recurring_expenses[0].months_seen == 2
    # Ja caiu em abril, entao nao conta como compromisso a descontar.
    assert context.recurring_expenses[0].pending_this_month is False
    assert context.committed_this_month == Decimal("0")


def test_empty_account_has_no_data(client, auth_headers, db_session):
    context = build_financial_context(db_session, _owner_id(client, auth_headers))

    assert not context.has_data
    assert context.month_income == Decimal("0")
    assert context.spending_by_category == []


def test_goal_deadline_becomes_a_monthly_amount(client, auth_headers, db_session):
    client.post(
        "/goals",
        headers=auth_headers,
        json={
            "title": "Viagem",
            "target_amount": "6000.00",
            "saved_amount": "1500.00",
            "deadline": "2026-10-01",
        },
    )

    context = build_financial_context(
        db_session, _owner_id(client, auth_headers), today=date(2026, 4, 1)
    )
    goal = context.goals[0]
    assert goal.months_left == 6
    assert goal.monthly_needed == Decimal("750.00")


# --- intents ---------------------------------------------------------------


@pytest.mark.parametrize(
    ("question", "expected"),
    [
        ("Quanto eu posso gastar essa semana?", Intent.SPENDING_CAPACITY),
        ("Quanto gastei com alimentação este mês?", Intent.CATEGORY_SPEND),
        ("Estou gastando demais?", Intent.OVERSPENDING),
        ("Quanto preciso guardar para minha meta?", Intent.GOALS),
        ("Como está minha situação financeira?", Intent.OVERVIEW),
        ("Quanto posso investir este mês?", Intent.INVESTING),
        ("Quais foram minhas maiores despesas?", Intent.BIGGEST_EXPENSES),
        ("Qual o saldo das minhas contas?", Intent.BALANCE),
        ("Tenho muitas assinaturas?", Intent.RECURRING),
        # Nomear a categoria muda a pergunta: sem "delivery" isto seria uma
        # pergunta sobre o mes inteiro.
        ("Estou gastando muito com delivery?", Intent.CATEGORY_SPEND),
        ("Meus tetos de gasto estao de pe?", Intent.BUDGETS),
        ("blablabla", Intent.UNKNOWN),
    ],
)
def test_detects_the_intent(question, expected):
    assert detect_intent(question) == expected


def test_repeated_phrases_do_not_inflate_an_intent():
    """"estou gastando muito" contem "gastando muito": as duas regras casam.

    Somando as duas, OVERSPENDING vencia qualquer outro intent da frase.
    """
    assert detect_intent("Estou gastando muito com supermercado?") == Intent.CATEGORY_SPEND


# --- offline provider ------------------------------------------------------


def _ask(db_session, owner_id, question, today=date(2026, 4, 20)):
    context = build_financial_context(db_session, owner_id, today=today)
    return asyncio.run(MockAIProvider().reply(question, context, []))


def test_offline_answer_carries_the_users_own_numbers(
    client, auth_headers, db_session, statement
):
    reply = _ask(db_session, _owner_id(client, auth_headers), "Quanto gastei com alimentação?")

    assert "R$ 1.240,00" in reply.content
    assert "Alimentação" in reply.content
    assert reply.used_context
    assert reply.provider == "mock"


def test_offline_answer_says_how_much_is_left_to_spend(
    client, auth_headers, db_session, statement
):
    reply = _ask(db_session, _owner_id(client, auth_headers), "Quanto eu posso gastar essa semana?")

    # 7.544,10 de sobra menos os 55,90 da Netflix, que ja caiu em abril.
    assert "R$ 7.544,10" in reply.content
    assert "semana" in reply.content


def test_spendable_discounts_the_bill_that_has_not_landed_yet(
    client, auth_headers, db_session, account
):
    """A conta que ainda vai cair nao e folga.

    Netflix aparece em fevereiro e marco pelo mesmo valor, entao e recorrente
    e ainda nao caiu em abril: os R$ 55,90 saem da sobra.
    """
    _income(client, auth_headers, account, "1000.00", "2026-04-05")
    _expense(client, auth_headers, account, "Netflix", "55.90", "2026-02-15")
    _expense(client, auth_headers, account, "Netflix", "55.90", "2026-03-15")

    reply = _ask(
        db_session,
        _owner_id(client, auth_headers),
        "Quanto posso gastar?",
        today=date(2026, 4, 10),
    )

    assert "R$ 944,10" in reply.content
    assert "R$ 55,90" in reply.content


def test_offline_answer_admits_when_there_is_nothing_to_analyse(
    client, auth_headers, db_session
):
    reply = _ask(db_session, _owner_id(client, auth_headers), "Quanto gastei com alimentação?")

    assert "Ainda não tenho lançamentos" in reply.content
    assert not reply.used_context


def test_offline_answer_does_not_invent_a_category(client, auth_headers, db_session, statement):
    reply = _ask(db_session, _owner_id(client, auth_headers), "Quanto gastei com cavalos?")

    assert "Não achei essa categoria" in reply.content
    assert "Alimentação" in reply.content


def test_greeting_works_without_any_data(client, auth_headers, db_session):
    reply = _ask(db_session, _owner_id(client, auth_headers), "Oi, tudo bem?")

    assert "FLORA" in reply.content
    assert not reply.used_context


# --- provider selection ----------------------------------------------------


def test_without_a_key_the_offline_provider_answers():
    assert build_provider(_settings()).name == "mock"


def test_with_a_key_claude_answers():
    assert build_provider(_settings(anthropic_api_key="sk-ant-exemplo")).name == "claude"


def test_forcing_claude_without_a_key_fails_at_boot():
    with pytest.raises(RuntimeError, match="ANTHROPIC_API_KEY"):
        build_provider(_settings(ai_provider="claude"))


def test_forcing_the_offline_provider_ignores_the_key():
    settings = _settings(ai_provider="mock", anthropic_api_key="sk-ant-exemplo")
    assert build_provider(settings).name == "mock"


def test_claude_provider_reports_itself_unconfigured_without_a_key():
    assert not ClaudeProvider(_settings()).is_configured


def test_claude_provider_refuses_to_call_without_a_key(client, auth_headers, db_session):
    context = build_financial_context(db_session, _owner_id(client, auth_headers))

    with pytest.raises(ServiceUnavailableError, match="ANTHROPIC_API_KEY"):
        asyncio.run(ClaudeProvider(_settings()).reply("oi", context, []))


def test_claude_provider_sends_the_key_as_a_header_and_reads_the_text(
    client, auth_headers, db_session, statement
):
    captured = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["key"] = request.headers.get("x-api-key")
        captured["version"] = request.headers.get("anthropic-version")
        return httpx.Response(
            200, json={"content": [{"type": "text", "text": "Sobram R$ 7.544,10."}]}
        )

    transport = httpx.MockTransport(handler)
    provider = ClaudeProvider(
        _settings(anthropic_api_key="sk-ant-exemplo"),
        client=httpx.AsyncClient(transport=transport),
    )
    context = build_financial_context(
        db_session, _owner_id(client, auth_headers), today=date(2026, 4, 20)
    )

    reply = asyncio.run(provider.reply("Quanto posso gastar?", context, []))

    assert reply.content == "Sobram R$ 7.544,10."
    assert reply.provider == "claude"
    assert captured["key"] == "sk-ant-exemplo"
    assert captured["version"] == "2023-06-01"


def test_a_failing_claude_falls_back_to_the_offline_answer(
    client, auth_headers, db_session, statement
):
    class BrokenProvider(AIProvider):
        name = "claude"

        async def reply(self, message, context, history):
            raise ServiceUnavailableError("api fora do ar")

    service = AIService(BrokenProvider())
    reply = asyncio.run(
        service.answer(
            db_session,
            _owner_id(client, auth_headers),
            "Quanto gastei com alimentação?",
            today=date(2026, 4, 20),
        )
    )

    assert "R$ 1.240,00" in reply.content
    assert reply.metadata["degraded"] == "true"


# --- prompt ----------------------------------------------------------------


def test_prompt_context_never_carries_the_key(client, auth_headers, db_session, statement):
    context = build_financial_context(
        db_session, _owner_id(client, auth_headers), today=date(2026, 4, 20)
    )
    rendered = render_context(context)

    assert "R$ 1.240,00" in rendered
    assert "sk-ant" not in rendered
    assert "ANTHROPIC" not in rendered


# --- endpoint --------------------------------------------------------------


def test_chat_requires_authentication(client):
    assert client.post("/ai/chat", json={"message": "oi"}).status_code == 401


def test_chat_answers_with_the_users_numbers(client, auth_headers, statement_this_month):
    response = client.post(
        "/ai/chat", headers=auth_headers, json={"message": "Quais foram minhas maiores despesas?"}
    )

    assert response.status_code == 200
    body = response.json()
    assert body["provider"] == "mock"
    assert body["used_context"] is True
    assert "Supermercado" in body["content"]


def test_chat_rejects_an_empty_message(client, auth_headers):
    assert client.post("/ai/chat", headers=auth_headers, json={"message": ""}).status_code == 422


def test_chat_rejects_an_oversized_message(client, auth_headers):
    response = client.post("/ai/chat", headers=auth_headers, json={"message": "a" * 2001})
    assert response.status_code == 422


def test_chat_caps_the_history_it_accepts(client, auth_headers):
    history = [{"role": "user", "content": "oi"} for _ in range(21)]
    response = client.post(
        "/ai/chat", headers=auth_headers, json={"message": "oi", "history": history}
    )
    assert response.status_code == 422


def test_chat_accepts_previous_turns(client, auth_headers, statement_this_month):
    response = client.post(
        "/ai/chat",
        headers=auth_headers,
        json={
            "message": "E quanto posso gastar?",
            "history": [
                {"role": "user", "content": "Como estão minhas finanças?"},
                {"role": "assistant", "content": "Entraram R$ 9.250,00."},
            ],
        },
    )
    assert response.status_code == 200


def test_chat_never_reads_another_users_statement(client, auth_headers, statement_this_month):
    client.post(
        "/auth/register",
        json={"name": "Intruso", "email": "intruso@florg.com.br", "password": "senha-forte-123"},
    )
    token = client.post(
        "/auth/login", data={"username": "intruso@florg.com.br", "password": "senha-forte-123"}
    ).json()["access_token"]

    response = client.post(
        "/ai/chat",
        headers={"Authorization": f"Bearer {token}"},
        json={"message": "Quais foram minhas maiores despesas?"},
    )

    assert response.status_code == 200
    assert "Supermercado" not in response.json()["content"]


def test_status_reports_the_provider(client, auth_headers):
    body = client.get("/ai/status", headers=auth_headers).json()

    assert body["provider"] == "mock"
    assert body["is_live"] is False
    assert len(body["suggestions"]) == 4


def test_context_endpoint_returns_the_same_numbers(client, auth_headers, statement_this_month):
    body = client.get("/ai/context", headers=auth_headers).json()["context"]

    assert body["month_income"] is not None
    assert "spending_by_category" in body


def test_endpoint_uses_the_injected_service(client, auth_headers, statement_this_month):
    """The router must take whatever provider the service hands it."""

    class StubProvider(AIProvider):
        name = "stub"

        async def reply(self, message, context, history):
            return AIReply(content="resposta do provider injetado", provider=self.name)

    app.dependency_overrides[get_ai_service] = lambda: AIService(StubProvider())
    try:
        body = client.post("/ai/chat", headers=auth_headers, json={"message": "oi"}).json()
    finally:
        app.dependency_overrides.pop(get_ai_service)

    assert body["content"] == "resposta do provider injetado"
    assert body["provider"] == "stub"


def test_chat_turn_roles_match_the_api(client, auth_headers):
    turn = ChatTurn(role=ChatRole.USER, content="oi")
    assert turn.role.value == "user"
