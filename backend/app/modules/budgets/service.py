import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.modules.budgets.models import Budget
from app.modules.budgets.schemas import BudgetStatus, BudgetUpsert, first_day_of_month
from app.modules.categorization.models import Category
from app.modules.insights import service as insights_service


def list_budgets(db: Session, owner_id: uuid.UUID, month: date | None = None) -> list[Budget]:
    statement = select(Budget).where(Budget.owner_id == owner_id)
    if month is not None:
        statement = statement.where(Budget.month == first_day_of_month(month))
    return list(db.scalars(statement.order_by(Budget.month.desc())))


def upsert_budget(db: Session, owner_id: uuid.UUID, data: BudgetUpsert) -> Budget:
    """One ceiling per category per month: setting it again replaces it.

    A POST that created a second row for the same month would leave the app
    showing two different limits for the same category.
    """
    if db.get(Category, data.category_id) is None:
        raise NotFoundError("Categoria não encontrada")

    budget = db.scalar(
        select(Budget).where(
            Budget.owner_id == owner_id,
            Budget.category_id == data.category_id,
            Budget.month == data.month,
        )
    )
    if budget is None:
        budget = Budget(owner_id=owner_id, **data.model_dump())
        db.add(budget)
    else:
        budget.limit_amount = data.limit_amount

    db.commit()
    db.refresh(budget)
    return budget


def delete_budget(db: Session, owner_id: uuid.UUID, budget_id: uuid.UUID) -> None:
    budget = db.scalar(select(Budget).where(Budget.id == budget_id, Budget.owner_id == owner_id))
    if budget is None:
        raise NotFoundError("Orçamento não encontrado")
    db.delete(budget)
    db.commit()


def budget_status(db: Session, owner_id: uuid.UUID, month: date) -> list[BudgetStatus]:
    """The month's ceilings with what was actually spent against each one."""
    spent_by_category = {
        summary.category_id: summary.total
        for summary in insights_service.spending_by_category(db, owner_id, month)
    }
    names = dict(db.execute(select(Category.id, Category.name)).all())

    result = []
    for budget in list_budgets(db, owner_id, month):
        spent = spent_by_category.get(budget.category_id, Decimal("0"))
        result.append(
            BudgetStatus(
                category_id=budget.category_id,
                category_name=names.get(budget.category_id, "Outros"),
                month=budget.month,
                limit_amount=budget.limit_amount,
                spent=spent,
                remaining=budget.limit_amount - spent,
            )
        )
    result.sort(key=lambda item: item.category_name)
    return result
