from decimal import Decimal


def _add(client, headers, account, amount, type_, description="Item", when="2026-08-10"):
    return client.post(
        "/transactions",
        headers=headers,
        json={
            "account_id": account["id"],
            "description": description,
            "amount": amount,
            "type": type_,
            "occurred_at": when,
        },
    )


def test_dashboard_totals(client, auth_headers, account):
    _add(client, auth_headers, account, "500.00", "income")
    _add(client, auth_headers, account, "120.00", "expense")
    _add(client, auth_headers, account, "80.00", "expense")

    summary = client.get("/insights/dashboard?month=2026-08-15", headers=auth_headers).json()

    assert Decimal(summary["month_income"]) == Decimal("500.00")
    assert Decimal(summary["month_expenses"]) == Decimal("200.00")
    assert Decimal(summary["month_net"]) == Decimal("300.00")
    assert Decimal(summary["total_balance"]) == Decimal("1300.00")
    assert summary["transaction_count"] == 3


def test_dashboard_ignores_other_months(client, auth_headers, account):
    _add(client, auth_headers, account, "500.00", "income", when="2026-07-10")
    summary = client.get("/insights/dashboard?month=2026-08-15", headers=auth_headers).json()
    assert Decimal(summary["month_income"]) == Decimal("0")
    # The total balance is cumulative, though, and includes the previous month.
    assert Decimal(summary["total_balance"]) == Decimal("1500.00")


def test_spending_by_category(client, auth_headers, account):
    _add(client, auth_headers, account, "100.00", "expense", description="iFood jantar")
    _add(client, auth_headers, account, "50.00", "expense", description="Uber centro")

    summary = client.get("/insights/dashboard?month=2026-08-15", headers=auth_headers).json()
    by_name = {c["category_name"]: Decimal(c["total"]) for c in summary["spending_by_category"]}

    assert by_name["Alimentação"] == Decimal("100.00")
    assert by_name["Transporte"] == Decimal("50.00")
