import uuid
from decimal import Decimal

from pydantic import BaseModel, ConfigDict

from app.modules.accounts.models import AccountType


class AccountCreate(BaseModel):
    name: str
    type: AccountType
    balance: Decimal = Decimal("0")


class AccountRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    type: AccountType
    balance: Decimal
