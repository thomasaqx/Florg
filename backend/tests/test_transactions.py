from decimal import Decimal


def _balance(client, auth_headers, account_id):
    accounts = client.get("/accounts", headers=auth_headers).json()
    return Decimal(next(a["balance"] for a in accounts if a["id"] == account_id))


def _new_transaction(client, auth_headers, account, **overrides):
    payload = {
        "account_id": account["id"],
        "description": "Mercado do bairro",
        "amount": "150.00",
        "type": "expense",
        "occurred_at": "2026-08-10",
    }
    payload.update(overrides)
    return client.post("/transactions", headers=auth_headers, json=payload)


def test_expense_decreases_balance(client, auth_headers, account):
    _new_transaction(client, auth_headers, account, amount="150.00", type="expense")
    assert _balance(client, auth_headers, account["id"]) == Decimal("850.00")


def test_income_increases_balance(client, auth_headers, account):
    _new_transaction(client, auth_headers, account, amount="200.00", type="income")
    assert _balance(client, auth_headers, account["id"]) == Decimal("1200.00")


def test_amount_must_be_positive(client, auth_headers, account):
    response = _new_transaction(client, auth_headers, account, amount="-50.00")
    assert response.status_code == 422


def test_editing_amount_keeps_balance_consistent(client, auth_headers, account):
    """The classic bug: editing without reverting the old effect drifts the balance."""
    created = _new_transaction(
        client, auth_headers, account, amount="150.00", type="expense"
    ).json()
    assert _balance(client, auth_headers, account["id"]) == Decimal("850.00")

    client.patch(
        f"/transactions/{created['id']}", headers=auth_headers, json={"amount": "50.00"}
    )
    # 1000 - 50, not 850 - 50.
    assert _balance(client, auth_headers, account["id"]) == Decimal("950.00")


def test_flipping_type_keeps_balance_consistent(client, auth_headers, account):
    created = _new_transaction(
        client, auth_headers, account, amount="100.00", type="expense"
    ).json()
    client.patch(
        f"/transactions/{created['id']}", headers=auth_headers, json={"type": "income"}
    )
    assert _balance(client, auth_headers, account["id"]) == Decimal("1100.00")


def test_delete_reverts_balance(client, auth_headers, account):
    created = _new_transaction(
        client, auth_headers, account, amount="150.00", type="expense"
    ).json()
    response = client.delete(f"/transactions/{created['id']}", headers=auth_headers)
    assert response.status_code == 204
    assert _balance(client, auth_headers, account["id"]) == Decimal("1000.00")


def test_moving_transaction_between_accounts_adjusts_both(client, auth_headers, account):
    second = client.post(
        "/accounts",
        headers=auth_headers,
        json={"name": "Carteira", "type": "wallet", "balance": "500.00"},
    ).json()

    created = _new_transaction(
        client, auth_headers, account, amount="100.00", type="expense"
    ).json()
    client.patch(
        f"/transactions/{created['id']}",
        headers=auth_headers,
        json={"account_id": second["id"]},
    )

    assert _balance(client, auth_headers, account["id"]) == Decimal("1000.00")
    assert _balance(client, auth_headers, second["id"]) == Decimal("400.00")


def test_sequence_of_operations_never_drifts(client, auth_headers, account):
    """The balance after several operations must match an independent tally."""
    a = _new_transaction(client, auth_headers, account, amount="300.00", type="expense").json()
    _new_transaction(client, auth_headers, account, amount="500.00", type="income")
    c = _new_transaction(client, auth_headers, account, amount="120.50", type="expense").json()

    client.patch(f"/transactions/{a['id']}", headers=auth_headers, json={"amount": "100.00"})
    client.delete(f"/transactions/{c['id']}", headers=auth_headers)

    # 1000 - 100 + 500 = 1400
    assert _balance(client, auth_headers, account["id"]) == Decimal("1400.00")


def test_transaction_is_auto_categorized(client, auth_headers, account):
    created = _new_transaction(
        client, auth_headers, account, description="iFood almoco"
    ).json()
    categories = client.get("/categories").json()
    alimentacao = next(c for c in categories if c["name"] == "Alimentação")
    assert created["category_id"] == alimentacao["id"]


def test_list_returns_all_accounts_transactions(client, auth_headers, account):
    second = client.post(
        "/accounts",
        headers=auth_headers,
        json={"name": "Carteira", "type": "wallet", "balance": "0.00"},
    ).json()
    _new_transaction(client, auth_headers, account)
    _new_transaction(client, auth_headers, second)

    response = client.get("/transactions", headers=auth_headers)
    assert response.status_code == 200
    assert len(response.json()) == 2
