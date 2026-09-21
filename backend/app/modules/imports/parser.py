"""Reads a bank statement out of a spreadsheet and turns it into rows we can import.

Two things make real statements messy: every bank names its columns differently,
and pt-BR files mix "1.234,56" with "1234.56" depending on who exported them.
Everything here exists to deal with one of those two problems.
"""

import csv
import io
import re
import unicodedata
from datetime import date, datetime
from decimal import Decimal, InvalidOperation

from openpyxl import load_workbook

# How many rows we look at when guessing which column is which.
SAMPLE_ROWS = 40

# Longest file we accept, in bytes. A statement with 10k lines is well under this.
MAX_FILE_BYTES = 5 * 1024 * 1024

MAX_ROWS = 10_000

XLSX_SUFFIXES = (".xlsx", ".xlsm")
CSV_SUFFIXES = (".csv", ".txt")

# Header names seen in exports from Itaú, Nubank, Bradesco, BB, Inter and C6,
# plus the ones Excel produces when a user builds the sheet by hand.
DATE_HEADERS = (
    "data",
    "data lancamento",
    "data do lancamento",
    "data de lancamento",
    "data movimento",
    "data da compra",
    "data compra",
    "dt",
    "date",
)
DESCRIPTION_HEADERS = (
    "descricao",
    "historico",
    "lancamento",
    "lancamentos",
    "detalhe",
    "detalhes",
    "estabelecimento",
    "titulo",
    "memo",
    "description",
)
AMOUNT_HEADERS = (
    "valor",
    "valor r$",
    "quantia",
    "montante",
    "amount",
    "value",
)
TYPE_HEADERS = ("tipo", "natureza", "operacao", "type", "d/c", "debito credito")

# Tokens that mark a row as money going out / money coming in when the file has
# an explicit type column instead of a signed amount.
EXPENSE_TOKENS = ("debito", "debit", "despesa", "saida", "pagamento", "compra", "d", "-")
INCOME_TOKENS = ("credito", "credit", "receita", "entrada", "deposito", "recebimento", "c", "+")

# Balance columns look a lot like amount columns. Naming them here keeps the
# detector from picking "Saldo" when "Valor" is also present.
BALANCE_HEADERS = ("saldo", "saldo atual", "balance")


class SpreadsheetError(Exception):
    """The file cannot be read at all, so there is nothing to preview."""


def normalize(value: object) -> str:
    """Lowercases, strips accents and collapses spaces, for header matching."""
    text = str(value or "").strip().lower()
    decomposed = unicodedata.normalize("NFKD", text)
    without_accents = "".join(char for char in decomposed if not unicodedata.combining(char))
    return re.sub(r"\s+", " ", without_accents).strip()


def parse_amount(raw: object) -> Decimal | None:
    """Parses a money cell, accepting both pt-BR and en-US decimal separators.

    Returns None when the cell holds no parseable number. The sign is preserved:
    the caller uses it to tell an expense from an income.
    """
    if raw is None:
        return None
    if isinstance(raw, bool):
        return None
    if isinstance(raw, (int, float, Decimal)):
        return Decimal(str(raw))

    text = str(raw).strip()
    if not text:
        return None

    # Accounting style: (1.234,56) means negative.
    negative_parens = text.startswith("(") and text.endswith(")")
    if negative_parens:
        text = text[1:-1]

    text = re.sub(r"[R$\s\u00a0]", "", text, flags=re.IGNORECASE)
    if not text:
        return None

    sign = -1 if text.startswith("-") else 1
    text = text.lstrip("+-")
    if not text:
        return None

    has_comma = "," in text
    has_dot = "." in text
    if has_comma and has_dot:
        # Whichever separator comes last is the decimal one: "1.234,56" vs "1,234.56".
        decimal_sep = "," if text.rfind(",") > text.rfind(".") else "."
        thousands_sep = "." if decimal_sep == "," else ","
        text = text.replace(thousands_sep, "").replace(decimal_sep, ".")
    elif has_comma:
        text = text.replace(",", ".")
    elif has_dot:
        # A lone dot is a thousands separator when it splits the number into
        # groups of exactly three ("1.234"), otherwise it is decimal ("12.34").
        groups = text.split(".")
        if len(groups) > 2 or (len(groups) == 2 and len(groups[1]) == 3):
            text = text.replace(".", "")

    try:
        parsed = Decimal(text)
    except InvalidOperation:
        return None

    if negative_parens:
        sign = -1
    return (parsed * sign).quantize(Decimal("0.01"))


_DATE_PATTERNS = (
    "%d/%m/%Y",
    "%d/%m/%y",
    "%d-%m-%Y",
    "%d-%m-%y",
    "%Y-%m-%d",
    "%Y/%m/%d",
    "%d.%m.%Y",
    "%d.%m.%y",
)


def parse_date(raw: object) -> date | None:
    """Parses a date cell. Day-first is tried before month-first, as in pt-BR."""
    if raw is None:
        return None
    if isinstance(raw, datetime):
        return raw.date()
    if isinstance(raw, date):
        return raw

    text = str(raw).strip()
    if not text:
        return None
    # Drop a time part if the file carries one ("01/04/2026 14:32").
    text = text.split(" ")[0].split("T")[0]

    for pattern in _DATE_PATTERNS:
        try:
            return datetime.strptime(text, pattern).date()
        except ValueError:
            continue
    return None


def parse_type(raw: object) -> str | None:
    """Reads an explicit type column. Returns 'income', 'expense' or None."""
    text = normalize(raw)
    if not text:
        return None
    if text in INCOME_TOKENS:
        return "income"
    if text in EXPENSE_TOKENS:
        return "expense"
    for token in INCOME_TOKENS:
        if len(token) > 1 and token in text:
            return "income"
    for token in EXPENSE_TOKENS:
        if len(token) > 1 and token in text:
            return "expense"
    return None


def _read_xlsx(content: bytes) -> list[list[object]]:
    try:
        workbook = load_workbook(io.BytesIO(content), data_only=True, read_only=True)
    except Exception as error:  # openpyxl raises a zoo of exceptions on bad files
        raise SpreadsheetError(
            "Não consegui abrir a planilha. Confira se o arquivo é .xlsx e não está corrompido."
        ) from error

    try:
        sheet = workbook.active
        if sheet is None:
            raise SpreadsheetError("A planilha está vazia.")
        rows: list[list[object]] = []
        for row in sheet.iter_rows(values_only=True):
            rows.append(list(row))
            if len(rows) > MAX_ROWS + SAMPLE_ROWS:
                break
        return rows
    finally:
        workbook.close()


def _decode_csv(content: bytes) -> str:
    for encoding in ("utf-8-sig", "utf-8", "cp1252", "latin-1"):
        try:
            return content.decode(encoding)
        except UnicodeDecodeError:
            continue
    raise SpreadsheetError("Não consegui ler o texto do arquivo. Salve como UTF-8 e tente de novo.")


def _read_csv(content: bytes) -> list[list[object]]:
    text = _decode_csv(content)
    sample = text[:8192]
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=";,\t|")
        delimiter = dialect.delimiter
    except csv.Error:
        # Exports from pt-BR Excel default to ';', so prefer it when both appear.
        delimiter = ";" if sample.count(";") >= sample.count(",") else ","

    reader = csv.reader(io.StringIO(text), delimiter=delimiter)
    return [list(row) for row in reader]


def read_rows(filename: str, content: bytes) -> list[list[object]]:
    """Returns the raw grid of the file, header row included."""
    if not content:
        raise SpreadsheetError("O arquivo está vazio.")
    if len(content) > MAX_FILE_BYTES:
        raise SpreadsheetError(
            f"Arquivo maior que {MAX_FILE_BYTES // (1024 * 1024)} MB. "
            "Divida o extrato em períodos menores."
        )

    lowered = (filename or "").lower()
    if lowered.endswith(XLSX_SUFFIXES):
        return _read_xlsx(content)
    if lowered.endswith(CSV_SUFFIXES):
        return _read_csv(content)
    if lowered.endswith(".xls"):
        raise SpreadsheetError(
            "O formato .xls antigo não é aceito. Abra no Excel e salve como .xlsx ou .csv."
        )
    raise SpreadsheetError("Formato não aceito. Envie um arquivo .xlsx ou .csv.")


def find_header_row(rows: list[list[object]]) -> int:
    """Finds the header row, skipping the bank's logo and account summary at the top.

    The header is the first row where at least two of our known column names
    appear. Falling back to row 0 keeps hand-made sheets working.
    """
    known = set(DATE_HEADERS) | set(DESCRIPTION_HEADERS) | set(AMOUNT_HEADERS) | set(TYPE_HEADERS)
    for index, row in enumerate(rows[:SAMPLE_ROWS]):
        cells = {normalize(cell) for cell in row if cell is not None}
        if len(cells & known) >= 2:
            return index
    return 0


def _match_column(headers: list[str], candidates: tuple[str, ...]) -> int | None:
    # Exact match first: "Valor" must win over "Valor do saldo anterior".
    for index, header in enumerate(headers):
        if header in candidates:
            return index
    for index, header in enumerate(headers):
        if header and any(candidate in header for candidate in candidates):
            return index
    return None


def balance_columns(headers: list[str]) -> set[int]:
    """Indexes of running-balance columns, which must never be read as the amount."""
    return {
        index
        for index, header in enumerate(normalize(item) for item in headers)
        if header in BALANCE_HEADERS
    }


def detect_columns(headers: list[str]) -> dict[str, int | None]:
    """Guesses which column holds the date, the description, the amount and the type."""
    normalized = [normalize(header) for header in headers]

    return {
        "date": _match_column(normalized, DATE_HEADERS),
        "description": _match_column(normalized, DESCRIPTION_HEADERS),
        "amount": _match_column(normalized, AMOUNT_HEADERS),
        "type": _match_column(normalized, TYPE_HEADERS),
    }


def infer_columns_by_content(
    rows: list[list[object]],
    mapping: dict[str, int | None],
    width: int,
    excluded: set[int] | None = None,
) -> dict[str, int | None]:
    """Fills in whatever the header names did not reveal, by looking at the values.

    A sheet exported without headers, or with headers in a language we do not
    know, still has a date-shaped column and a number-shaped column.
    """
    resolved = dict(mapping)
    taken = {index for index in resolved.values() if index is not None}
    taken |= excluded or set()

    if resolved["date"] is None:
        for column in range(width):
            if column in taken:
                continue
            hits = sum(1 for row in rows if parse_date(cell(row, column)) is not None)
            if hits >= max(1, len(rows) // 2):
                resolved["date"] = column
                taken.add(column)
                break

    if resolved["amount"] is None:
        best_column: int | None = None
        best_hits = 0
        for column in range(width):
            if column in taken:
                continue
            hits = sum(1 for row in rows if parse_amount(cell(row, column)) is not None)
            if hits > best_hits:
                best_column, best_hits = column, hits
        if best_column is not None and best_hits >= max(1, len(rows) // 2):
            resolved["amount"] = best_column
            taken.add(best_column)

    if resolved["description"] is None:
        best_column = None
        best_length = 0
        for column in range(width):
            if column in taken:
                continue
            texts = [str(cell(row, column) or "") for row in rows]
            # The description is the wordiest column left.
            average = sum(len(text) for text in texts) / max(1, len(texts))
            if average > best_length:
                best_column, best_length = column, average
        if best_column is not None and best_length > 0:
            resolved["description"] = best_column

    return resolved


def cell(row: list[object], index: int | None) -> object:
    if index is None or index < 0 or index >= len(row):
        return None
    return row[index]


def is_blank(row: list[object]) -> bool:
    return all(cell is None or str(cell).strip() == "" for cell in row)
