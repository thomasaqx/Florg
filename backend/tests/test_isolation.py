"""A user must never read or modify another user's financial data.

In fintech this is the most severe failure possible (IDOR). Every route that
takes a client-supplied id must prove ownership, not just existence.
"""

import pytest


@pytest.fixture
def other_user_headers(client):
    client.post(
        "/auth/register",
        json={"name": "Intruso", "email": "intruso@florg.com.br", "password": "senha-forte-123"},
    )
    response = client.post(
        "/auth/login",
        data={"username": "intruso@florg.com.br", "password": "senha-forte-123"},
    )
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def _transaction_of(client, headers, account):
    return client.post(
        "/transactions",
        headers=headers,
        json={
            "account_id": account["id"],
            "description": "Compra",
            "amount": "100.00",
            "type": "expense",
            "occurred_at": "2026-08-10",
        },
    ).json()


def test_cannot_list_other_users_accounts(client, auth_headers, account, other_user_headers):
    assert client.get("/accounts", headers=other_user_headers).json() == []


def test_cannot_read_other_users_transactions(
    client, auth_headers, account, other_user_headers
):
    _transaction_of(client, auth_headers, account)
    assert client.get("/transactions", headers=other_user_headers).json() == []
    assert (
        client.get(f"/transactions/account/{account['id']}", headers=other_user_headers).json()
        == []
    )


def test_cannot_create_transaction_in_other_users_account(
    client, auth_headers, account, other_user_headers
):
    response = client.post(
        "/transactions",
        headers=other_user_headers,
        json={
            "account_id": account["id"],
            "description": "Invasao",
            "amount": "999.00",
            "type": "expense",
            "occurred_at": "2026-08-10",
        },
    )
    assert response.status_code == 404


def test_cannot_edit_other_users_transaction(client, auth_headers, account, other_user_headers):
    created = _transaction_of(client, auth_headers, account)
    response = client.patch(
        f"/transactions/{created['id']}", headers=other_user_headers, json={"amount": "1.00"}
    )
    assert response.status_code == 404


def test_cannot_delete_other_users_transaction(
    client, auth_headers, account, other_user_headers
):
    created = _transaction_of(client, auth_headers, account)
    response = client.delete(f"/transactions/{created['id']}", headers=other_user_headers)
    assert response.status_code == 404


def test_dashboard_only_counts_own_data(client, auth_headers, account, other_user_headers):
    _transaction_of(client, auth_headers, account)
    summary = client.get("/insights/dashboard", headers=other_user_headers).json()
    assert summary["total_balance"] == "0.00" or float(summary["total_balance"]) == 0
    assert summary["transaction_count"] == 0
