"""Spending ceilings, and the month's spending measured against them."""

import pytest


@pytest.fixture
def food_category(client):
    categories = client.get("/categories").json()
    return next(item for item in categories if item["name"] == "Alimentação")


def _set_budget(client, auth_headers, category_id, *, month="2026-04-15", limit="1500.00"):
    return client.put(
        "/budgets",
        headers=auth_headers,
        json={"category_id": category_id, "month": month, "limit_amount": limit},
    )


def test_any_day_of_the_month_stores_the_first(client, auth_headers, food_category):
    response = _set_budget(client, auth_headers, food_category["id"], month="2026-04-23")
    assert response.status_code == 200
    assert response.json()["month"] == "2026-04-01"


def test_setting_the_same_month_twice_replaces_the_limit(client, auth_headers, food_category):
    first = _set_budget(client, auth_headers, food_category["id"], limit="1500.00").json()
    second = _set_budget(client, auth_headers, food_category["id"], limit="1200.00").json()

    assert first["id"] == second["id"]
    assert second["limit_amount"] == "1200.00"
    assert len(client.get("/budgets", headers=auth_headers).json()) == 1


def test_unknown_category_is_rejected(client, auth_headers):
    response = _set_budget(
        client, auth_headers, "00000000-0000-0000-0000-000000000000"
    )
    assert response.status_code == 404


def test_status_subtracts_the_months_spending(
    client, auth_headers, account, food_category
):
    _set_budget(client, auth_headers, food_category["id"], limit="1500.00")
    client.post(
        "/transactions",
        headers=auth_headers,
        json={
            "account_id": account["id"],
            "description": "Supermercado do mes",
            "amount": "1240.00",
            "type": "expense",
            "occurred_at": "2026-04-10",
        },
    )

    status_rows = client.get(
        "/budgets/status", headers=auth_headers, params={"month": "2026-04-01"}
    ).json()

    assert len(status_rows) == 1
    row = status_rows[0]
    assert row["category_name"] == "Alimentação"
    assert row["spent"] == "1240.00"
    assert row["remaining"] == "260.00"


def test_status_ignores_another_month(client, auth_headers, account, food_category):
    _set_budget(client, auth_headers, food_category["id"], month="2026-04-01")
    client.post(
        "/transactions",
        headers=auth_headers,
        json={
            "account_id": account["id"],
            "description": "Supermercado",
            "amount": "300.00",
            "type": "expense",
            "occurred_at": "2026-03-10",
        },
    )

    row = client.get(
        "/budgets/status", headers=auth_headers, params={"month": "2026-04-01"}
    ).json()[0]
    assert row["spent"] == "0"


def test_filters_by_month(client, auth_headers, food_category):
    _set_budget(client, auth_headers, food_category["id"], month="2026-04-01")
    _set_budget(client, auth_headers, food_category["id"], month="2026-05-01")

    april = client.get("/budgets", headers=auth_headers, params={"month": "2026-04-20"}).json()
    assert len(april) == 1
    assert april[0]["month"] == "2026-04-01"
    assert len(client.get("/budgets", headers=auth_headers).json()) == 2


def test_cannot_delete_another_users_budget(client, auth_headers, food_category):
    budget = _set_budget(client, auth_headers, food_category["id"]).json()

    client.post(
        "/auth/register",
        json={"name": "Intruso", "email": "intruso@florg.com.br", "password": "senha-forte-123"},
    )
    token = client.post(
        "/auth/login", data={"username": "intruso@florg.com.br", "password": "senha-forte-123"}
    ).json()["access_token"]
    intruder = {"Authorization": f"Bearer {token}"}

    assert client.get("/budgets", headers=intruder).json() == []
    assert client.delete(f"/budgets/{budget['id']}", headers=intruder).status_code == 404
    assert client.delete(f"/budgets/{budget['id']}", headers=auth_headers).status_code == 204


def test_budgets_require_authentication(client):
    assert client.get("/budgets").status_code == 401
