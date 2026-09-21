import uuid
from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.modules.goals.models import GoalPriority

_MONEY = {"max_digits": 12, "decimal_places": 2}


class GoalCreate(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=500)
    target_amount: Decimal = Field(gt=0, **_MONEY)
    saved_amount: Decimal = Field(default=Decimal("0"), ge=0, **_MONEY)
    deadline: date | None = None
    priority: GoalPriority = GoalPriority.MEDIUM
    icon: str | None = Field(default=None, max_length=40)
    linked_account_id: uuid.UUID | None = None


class GoalUpdate(BaseModel):
    """PATCH: only the fields sent are changed."""

    title: str | None = Field(default=None, min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=500)
    target_amount: Decimal | None = Field(default=None, gt=0, **_MONEY)
    saved_amount: Decimal | None = Field(default=None, ge=0, **_MONEY)
    deadline: date | None = None
    priority: GoalPriority | None = None
    icon: str | None = Field(default=None, max_length=40)
    linked_account_id: uuid.UUID | None = None


class GoalRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    title: str
    description: str | None
    target_amount: Decimal
    saved_amount: Decimal
    deadline: date | None
    priority: GoalPriority
    icon: str | None
    linked_account_id: uuid.UUID | None


class GoalContribution(BaseModel):
    """Adds to (or, with a negative value, takes from) what is put aside."""

    amount: Decimal = Field(**_MONEY)
