import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.modules.transactions.models import TransactionType


class ColumnMapping(BaseModel):
    """Which column of the sheet holds each field, by zero-based index.

    The preview fills this in by itself. The user can correct it and ask for a
    new preview when the guess is wrong.
    """

    date: int | None = None
    description: int | None = None
    amount: int | None = None
    type: int | None = None


class ImportRow(BaseModel):
    """One line of the sheet after parsing.

    Rows that failed to parse come back too, with `error` filled in, so the user
    sees what was dropped instead of silently importing less than they sent.
    """

    line: int
    description: str
    amount: Decimal
    type: TransactionType
    occurred_at: date
    fingerprint: str
    error: str | None = None


class SkippedRow(BaseModel):
    line: int
    reason: str
    raw: list[str]


class ImportPreview(BaseModel):
    filename: str
    header_row: int
    headers: list[str]
    mapping: ColumnMapping
    total_rows: int
    rows: list[ImportRow]
    skipped: list[SkippedRow]
    # Rows already in this account, matched by fingerprint. Importing again
    # leaves them untouched.
    duplicate_count: int


class ImportCommit(BaseModel):
    account_id: uuid.UUID
    filename: str = Field(default="planilha", max_length=255)
    rows: list[ImportRow] = Field(min_length=1)


class ImportResult(BaseModel):
    batch_id: uuid.UUID
    imported: int
    duplicates: int
    account_balance: Decimal


class ImportBatchRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    account_id: uuid.UUID
    filename: str
    rows_imported: int
    rows_duplicated: int
    created_at: datetime
