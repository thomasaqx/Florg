"""pt-BR number and date formatting for anything FLORA says.

Kept apart from the providers so the offline answers and the prompt sent to
Claude show the same numbers written the same way.
"""

import unicodedata
from datetime import date
from decimal import ROUND_HALF_UP, Decimal

_MONTH_ABBREVIATIONS = [
    "jan",
    "fev",
    "mar",
    "abr",
    "mai",
    "jun",
    "jul",
    "ago",
    "set",
    "out",
    "nov",
    "dez",
]


def format_money(value: Decimal | float | int, *, decimals: int = 2) -> str:
    """R$ 1.234,56 -- thousands with a dot, cents with a comma."""
    amount = Decimal(str(value)).quantize(
        Decimal("1") if decimals == 0 else Decimal("0.01"), rounding=ROUND_HALF_UP
    )
    sign = "-" if amount < 0 else ""
    digits = f"{abs(amount):,.{decimals}f}"
    # en-US separators come out of the format spec; swap them for pt-BR.
    digits = digits.replace(",", "\x00").replace(".", ",").replace("\x00", ".")
    return f"{sign}R$ {digits}"


def format_percent(value: float, *, decimals: int = 0) -> str:
    formatted = f"{abs(value):.{decimals}f}".replace(".", ",")
    return f"{'-' if value < 0 else ''}{formatted}%"


def format_day(value: date) -> str:
    return f"{value.day} de {_MONTH_ABBREVIATIONS[value.month - 1]}"


def normalize(text: str) -> str:
    """Lowercases and drops accents, so "alimentação" matches "alimentacao"."""
    stripped = unicodedata.normalize("NFD", text.lower())
    return "".join(char for char in stripped if unicodedata.category(char) != "Mn")
