"""Importação de extrato por planilha.

O que precisa ser verdade para o recurso ser confiável: o mesmo arquivo enviado
duas vezes não pode duplicar lançamentos, o saldo tem que bater com a soma das
linhas, e linhas ilegíveis têm que aparecer como descartadas em vez de sumirem.
"""

import io
from decimal import Decimal

import pytest
from openpyxl import Workbook


def sheet_bytes(rows: list[list[object]]) -> bytes:
    workbook = Workbook()
    worksheet = workbook.active
    for row in rows:
        worksheet.append(row)
    buffer = io.BytesIO()
    workbook.save(buffer)
    return buffer.getvalue()


def upload(client, auth_headers, content: bytes, filename="extrato.xlsx", account_id=None):
    data = {}
    if account_id is not None:
        data["account_id"] = account_id
    return client.post(
        "/imports/preview",
        headers=auth_headers,
        files={"file": (filename, content)},
        data=data,
    )


@pytest.fixture
def statement() -> bytes:
    return sheet_bytes(
        [
            ["Data", "Histórico", "Valor"],
            ["01/04/2026", "Supermercado Extra", "-250,90"],
            ["02/04/2026", "Salário", "5.500,00"],
            ["03/04/2026", "Uber", "-32,40"],
        ]
    )


def test_preview_reads_ptbr_dates_and_amounts(client, auth_headers, statement):
    response = upload(client, auth_headers, statement)
    assert response.status_code == 200

    body = response.json()
    assert body["mapping"] == {"date": 0, "description": 1, "amount": 2, "type": None}
    assert [row["description"] for row in body["rows"]] == [
        "Supermercado Extra",
        "Salário",
        "Uber",
    ]
    assert body["rows"][0]["occurred_at"] == "2026-04-01"
    # O sinal define o tipo, e o valor guardado é sempre positivo.
    assert body["rows"][0]["type"] == "expense"
    assert Decimal(body["rows"][0]["amount"]) == Decimal("250.90")
    assert body["rows"][1]["type"] == "income"
    assert body["skipped"] == []


def test_commit_creates_transactions_and_moves_balance(client, auth_headers, account, statement):
    preview = upload(client, auth_headers, statement, account_id=account["id"]).json()
    assert preview["duplicate_count"] == 0

    response = client.post(
        "/imports/commit",
        headers=auth_headers,
        json={
            "account_id": account["id"],
            "filename": "extrato.xlsx",
            "rows": preview["rows"],
        },
    )
    assert response.status_code == 201

    result = response.json()
    assert result["imported"] == 3
    assert result["duplicates"] == 0
    # 1000 inicial - 250,90 + 5500 - 32,40
    assert Decimal(result["account_balance"]) == Decimal("6216.70")

    listed = client.get("/transactions", headers=auth_headers).json()
    assert len(listed) == 3


def test_importing_the_same_file_twice_does_not_duplicate(
    client, auth_headers, account, statement
):
    preview = upload(client, auth_headers, statement, account_id=account["id"]).json()
    payload = {
        "account_id": account["id"],
        "filename": "extrato.xlsx",
        "rows": preview["rows"],
    }
    client.post("/imports/commit", headers=auth_headers, json=payload)

    again = client.post("/imports/commit", headers=auth_headers, json=payload).json()
    assert again["imported"] == 0
    assert again["duplicates"] == 3
    # O saldo não pode andar de novo.
    assert Decimal(again["account_balance"]) == Decimal("6216.70")
    assert len(client.get("/transactions", headers=auth_headers).json()) == 3


def test_preview_warns_about_rows_already_imported(client, auth_headers, account, statement):
    preview = upload(client, auth_headers, statement, account_id=account["id"]).json()
    client.post(
        "/imports/commit",
        headers=auth_headers,
        json={"account_id": account["id"], "filename": "e.xlsx", "rows": preview["rows"]},
    )

    second = upload(client, auth_headers, statement, account_id=account["id"]).json()
    assert second["duplicate_count"] == 3


def test_two_identical_lines_in_one_file_both_import(client, auth_headers, account):
    content = sheet_bytes(
        [
            ["Data", "Descrição", "Valor"],
            ["05/04/2026", "Café", "-5,00"],
            ["05/04/2026", "Café", "-5,00"],
        ]
    )
    preview = upload(client, auth_headers, content, account_id=account["id"]).json()
    assert len(preview["rows"]) == 2
    # Duas linhas iguais precisam de impressões digitais diferentes, senão a
    # segunda seria descartada como repetida.
    assert preview["rows"][0]["fingerprint"] != preview["rows"][1]["fingerprint"]

    result = client.post(
        "/imports/commit",
        headers=auth_headers,
        json={"account_id": account["id"], "filename": "c.xlsx", "rows": preview["rows"]},
    ).json()
    assert result["imported"] == 2
    assert Decimal(result["account_balance"]) == Decimal("990.00")


def test_explicit_type_column_wins_over_the_sign(client, auth_headers, account):
    content = sheet_bytes(
        [
            ["Data", "Descrição", "Valor", "Tipo"],
            ["10/04/2026", "Estorno de compra", "150,00", "Crédito"],
            ["11/04/2026", "Farmácia", "40,00", "Débito"],
        ]
    )
    preview = upload(client, auth_headers, content, account_id=account["id"]).json()
    assert preview["mapping"]["type"] == 3
    assert preview["rows"][0]["type"] == "income"
    assert preview["rows"][1]["type"] == "expense"


def test_csv_with_semicolons_and_latin1(client, auth_headers, account):
    content = "Data;Descrição;Valor\n01/04/2026;Padaria São José;-18,50\n".encode("latin-1")
    preview = upload(client, auth_headers, content, filename="extrato.csv").json()
    assert preview["rows"][0]["description"] == "Padaria São José"
    assert Decimal(preview["rows"][0]["amount"]) == Decimal("18.50")


def test_unreadable_rows_are_reported_not_dropped_silently(client, auth_headers):
    content = sheet_bytes(
        [
            ["Data", "Descrição", "Valor"],
            ["01/04/2026", "Mercado", "-100,00"],
            ["data inválida", "Linha torta", "-50,00"],
            ["03/04/2026", "Sem valor", ""],
        ]
    )
    preview = upload(client, auth_headers, content).json()
    assert len(preview["rows"]) == 1
    assert preview["total_rows"] == 3
    reasons = [item["reason"] for item in preview["skipped"]]
    assert "Data em branco ou ilegível" in reasons
    assert "Valor em branco ou ilegível" in reasons


def test_header_below_a_bank_preamble_is_found(client, auth_headers):
    content = sheet_bytes(
        [
            ["Banco Exemplo S.A."],
            ["Extrato de conta corrente"],
            [],
            ["Data", "Histórico", "Valor", "Saldo"],
            ["01/04/2026", "Pix recebido", "300,00", "1.300,00"],
        ]
    )
    preview = upload(client, auth_headers, content).json()
    # A coluna "Saldo" não pode ser confundida com a de valor.
    assert preview["mapping"]["amount"] == 2
    assert len(preview["rows"]) == 1
    assert Decimal(preview["rows"][0]["amount"]) == Decimal("300.00")


def test_categorization_runs_on_imported_rows(client, auth_headers, account):
    content = sheet_bytes(
        [
            ["Data", "Descrição", "Valor"],
            ["01/04/2026", "IFOOD *LANCHONETE", "-45,00"],
        ]
    )
    preview = upload(client, auth_headers, content, account_id=account["id"]).json()
    client.post(
        "/imports/commit",
        headers=auth_headers,
        json={"account_id": account["id"], "filename": "i.xlsx", "rows": preview["rows"]},
    )

    transaction = client.get("/transactions", headers=auth_headers).json()[0]
    categories = {item["id"]: item["name"] for item in client.get("/categories").json()}
    assert categories[transaction["category_id"]] == "Alimentação"


def test_cannot_import_into_someone_elses_account(client, auth_headers, account, statement):
    preview = upload(client, auth_headers, statement).json()

    client.post(
        "/auth/register",
        json={"name": "Outro", "email": "outro@florg.com.br", "password": "outra-senha-123"},
    )
    other = client.post(
        "/auth/login",
        data={"username": "outro@florg.com.br", "password": "outra-senha-123"},
    ).json()["access_token"]

    response = client.post(
        "/imports/commit",
        headers={"Authorization": f"Bearer {other}"},
        json={"account_id": account["id"], "filename": "x.xlsx", "rows": preview["rows"]},
    )
    assert response.status_code == 404


def test_import_requires_authentication(client, statement):
    response = client.post(
        "/imports/preview", files={"file": ("extrato.xlsx", statement)}
    )
    assert response.status_code == 401


def test_rejects_a_file_that_is_not_a_spreadsheet(client, auth_headers):
    response = upload(client, auth_headers, b"isto nao e uma planilha", filename="foto.png")
    assert response.status_code == 422
    assert "Formato" in response.json()["detail"]


def test_batch_history_is_listed(client, auth_headers, account, statement):
    preview = upload(client, auth_headers, statement, account_id=account["id"]).json()
    client.post(
        "/imports/commit",
        headers=auth_headers,
        json={
            "account_id": account["id"],
            "filename": "marco-2026.xlsx",
            "rows": preview["rows"],
        },
    )

    batches = client.get("/imports", headers=auth_headers).json()
    assert len(batches) == 1
    assert batches[0]["filename"] == "marco-2026.xlsx"
    assert batches[0]["rows_imported"] == 3
