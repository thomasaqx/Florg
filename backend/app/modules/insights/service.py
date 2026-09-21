import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.modules.accounts.models import Account
from app.modules.categorization.models import Category
from app.modules.insights.schemas import CategorySummary, DashboardSummary
from app.modules.transactions.models import Transaction, TransactionType


def spending_by_category(db: Session, owner_id: uuid.UUID, month: date) -> list[CategorySummary]:
    rows = db.execute(
        select(Category.id, Category.name, func.sum(Transaction.amount))
        .select_from(Transaction)
        .join(Account, Account.id == Transaction.account_id)
        .outerjoin(Category, Category.id == Transaction.category_id)
        .where(
            Account.owner_id == owner_id,
            Transaction.type == TransactionType.EXPENSE,
            func.extract("year", Transaction.occurred_at) == month.year,
            func.extract("month", Transaction.occurred_at) == month.month,
        )
        .group_by(Category.id, Category.name)
    ).all()

    return [
        CategorySummary(category_id=row[0], category_name=row[1] or "Outros", total=row[2])
        for row in rows
    ]


def _month_total(
    db: Session, owner_id: uuid.UUID, month: date, type_: TransactionType
) -> Decimal:
    total = db.scalar(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .select_from(Transaction)
        .join(Account, Account.id == Transaction.account_id)
        .where(
            Account.owner_id == owner_id,
            Transaction.type == type_,
            func.extract("year", Transaction.occurred_at) == month.year,
            func.extract("month", Transaction.occurred_at) == month.month,
        )
    )
    return Decimal(total or 0)


def dashboard_summary(db: Session, owner_id: uuid.UUID, month: date) -> DashboardSummary:
    total_balance = db.scalar(
        select(func.coalesce(func.sum(Account.balance), 0)).where(Account.owner_id == owner_id)
    )

    transaction_count = db.scalar(
        select(func.count(Transaction.id))
        .select_from(Transaction)
        .join(Account, Account.id == Transaction.account_id)
        .where(Account.owner_id == owner_id)
    )

    income = _month_total(db, owner_id, month, TransactionType.INCOME)
    expenses = _month_total(db, owner_id, month, TransactionType.EXPENSE)

    return DashboardSummary(
        total_balance=Decimal(total_balance or 0),
        month_income=income,
        month_expenses=expenses,
        month_net=income - expenses,
        transaction_count=transaction_count or 0,
        spending_by_category=spending_by_category(db, owner_id, month),
    )
