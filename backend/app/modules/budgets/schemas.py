import uuid
from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator


def first_day_of_month(value: date) -> date:
    """Any day of the month identifies the month; the row always stores day 1."""
    return value.replace(day=1)


class BudgetUpsert(BaseModel):
    category_id: uuid.UUID
    month: date
    limit_amount: Decimal = Field(ge=0, max_digits=12, decimal_places=2)

    @field_validator("month")
    @classmethod
    def _normalize_month(cls, value: date) -> date:
        return first_day_of_month(value)


class BudgetRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    category_id: uuid.UUID
    month: date
    limit_amount: Decimal


class BudgetStatus(BaseModel):
    """A budget with the month's spending already applied to it."""

    category_id: uuid.UUID
    category_name: str
    month: date
    limit_amount: Decimal
    spent: Decimal
    remaining: Decimal
