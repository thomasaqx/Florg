import uuid
from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.modules.transactions.models import TransactionType


class TransactionCreate(BaseModel):
    account_id: uuid.UUID
    description: str = Field(min_length=1, max_length=200)
    amount: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    type: TransactionType
    occurred_at: date
    category_id: uuid.UUID | None = None


class TransactionUpdate(BaseModel):
    """All fields optional: this is a PATCH, only what is sent gets changed."""

    account_id: uuid.UUID | None = None
    description: str | None = Field(default=None, min_length=1, max_length=200)
    amount: Decimal | None = Field(default=None, gt=0, max_digits=12, decimal_places=2)
    type: TransactionType | None = None
    occurred_at: date | None = None
    category_id: uuid.UUID | None = None


class TransactionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    account_id: uuid.UUID
    category_id: uuid.UUID | None
    description: str
    amount: Decimal
    type: TransactionType
    occurred_at: date
