import uuid
from decimal import Decimal

from pydantic import BaseModel


class CategorySummary(BaseModel):
    category_id: uuid.UUID | None
    category_name: str
    total: Decimal


class DashboardSummary(BaseModel):
    """Dashboard headline figures, computed in the database rather than the app."""

    total_balance: Decimal
    month_income: Decimal
    month_expenses: Decimal
    month_net: Decimal
    transaction_count: int
    spending_by_category: list[CategorySummary]
