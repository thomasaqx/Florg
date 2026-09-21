"""The financial picture handed to FLORA before she answers anything.

This is the only place that reads the database for the AI. A provider receives
a FinancialContext and never touches a Session, which is what lets the offline
provider and Claude answer from exactly the same numbers.
"""

import uuid
from collections import defaultdict
from datetime import date, timedelta
from decimal import Decimal

from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.modules.accounts.models import Account, AccountType
from app.modules.budgets import service as budgets_service
from app.modules.categorization.models import Category
from app.modules.goals.models import Goal
from app.modules.transactions.models import Transaction, TransactionType

ZERO = Decimal("0")

# Only expenses repeated in at least this many distinct months count as
# recurring. Two coffees in the same week are not a subscription.
_RECURRING_MIN_MONTHS = 2
_TOP_EXPENSES = 5
_MONTH_NAMES = [
    "janeiro",
    "fevereiro",
    "março",
    "abril",
    "maio",
    "junho",
    "julho",
    "agosto",
    "setembro",
    "outubro",
    "novembro",
    "dezembro",
]


def month_label(value: date) -> str:
    return f"{_MONTH_NAMES[value.month - 1]} de {value.year}"


def first_day_of_month(value: date) -> date:
    return value.replace(day=1)


def last_day_of_month(value: date) -> date:
    if value.month == 12:
        return date(value.year, 12, 31)
    return date(value.year, value.month + 1, 1) - timedelta(days=1)


def previous_month(value: date) -> date:
    first = first_day_of_month(value)
    if first.month == 1:
        return date(first.year - 1, 12, 1)
    return date(first.year, first.month - 1, 1)


class AccountSnapshot(BaseModel):
    name: str
    type: str
    balance: Decimal


class CategorySpend(BaseModel):
    name: str
    total: Decimal
    share_of_expenses: float
    previous_month_total: Decimal | None = None
    change_percent: float | None = None


class BudgetSnapshot(BaseModel):
    category_name: str
    limit_amount: Decimal
    spent: Decimal
    remaining: Decimal
    used_percent: float


class GoalSnapshot(BaseModel):
    title: str
    target_amount: Decimal
    saved_amount: Decimal
    remaining: Decimal
    progress_percent: float
    deadline: date | None
    months_left: int | None
    monthly_needed: Decimal | None


class RecurringExpense(BaseModel):
    description: str
    amount: Decimal
    months_seen: int
    # Falso quando a cobranca ja apareceu no mes de referencia. O que ainda
    # nao caiu e compromisso, nao folga.
    pending_this_month: bool = False


class ExpenseSnapshot(BaseModel):
    description: str
    category_name: str
    amount: Decimal
    occurred_at: date


class InvestmentSnapshot(BaseModel):
    """Derived from cash flow, not from a portfolio.

    FLORG has no brokerage integration yet, so "investments" here means what
    the month leaves over and how long the balance would cover the expenses.
    """

    available_to_invest: Decimal
    reserve_months: float | None


class FinancialContext(BaseModel):
    """Everything FLORA is allowed to reason about, already computed."""

    as_of: date
    month_label: str
    days_left_in_month: int

    total_balance: Decimal
    month_income: Decimal
    month_expenses: Decimal
    month_net: Decimal
    savings_rate: float | None
    previous_month_expenses: Decimal

    transaction_count: int
    accounts: list[AccountSnapshot]
    spending_by_category: list[CategorySpend]
    budgets: list[BudgetSnapshot]
    goals: list[GoalSnapshot]
    recurring_expenses: list[RecurringExpense]
    top_expenses: list[ExpenseSnapshot]
    investments: InvestmentSnapshot
    liabilities: Decimal

    @property
    def has_data(self) -> bool:
        return self.transaction_count > 0 or bool(self.accounts)

    @property
    def has_month_data(self) -> bool:
        return self.month_income > ZERO or self.month_expenses > ZERO

    @property
    def recurring_total(self) -> Decimal:
        return sum((item.amount for item in self.recurring_expenses), ZERO)

    @property
    def committed_this_month(self) -> Decimal:
        """Recurring charges that have not landed in this month yet."""
        return sum(
            (item.amount for item in self.recurring_expenses if item.pending_this_month),
            ZERO,
        )


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
            Transaction.occurred_at >= first_day_of_month(month),
            Transaction.occurred_at <= last_day_of_month(month),
        )
    )
    return Decimal(total or 0)


def _category_totals(db: Session, owner_id: uuid.UUID, month: date) -> dict[str, Decimal]:
    rows = db.execute(
        select(Category.name, func.sum(Transaction.amount))
        .select_from(Transaction)
        .join(Account, Account.id == Transaction.account_id)
        .outerjoin(Category, Category.id == Transaction.category_id)
        .where(
            Account.owner_id == owner_id,
            Transaction.type == TransactionType.EXPENSE,
            Transaction.occurred_at >= first_day_of_month(month),
            Transaction.occurred_at <= last_day_of_month(month),
        )
        .group_by(Category.name)
    ).all()
    return {(name or "Sem categoria"): Decimal(total or 0) for name, total in rows}


def _percent_change(previous: Decimal, current: Decimal) -> float | None:
    """None when there is no base to compare against.

    A "+100%" coming out of a division by zero says less than showing nothing.
    """
    if previous <= ZERO:
        return None
    return float((current - previous) / previous * 100)


def _recurring_expenses(
    db: Session, owner_id: uuid.UUID, month: date
) -> list[RecurringExpense]:
    """Descriptions that repeat month after month for the same amount.

    Finds the subscription without the user having to tag anything.
    """
    rows = db.execute(
        select(Transaction.description, Transaction.amount, Transaction.occurred_at)
        .select_from(Transaction)
        .join(Account, Account.id == Transaction.account_id)
        .where(Account.owner_id == owner_id, Transaction.type == TransactionType.EXPENSE)
    ).all()

    months_by_key: dict[tuple[str, Decimal], set[tuple[int, int]]] = defaultdict(set)
    labels: dict[tuple[str, Decimal], str] = {}
    for description, amount, occurred_at in rows:
        key = (description.strip().lower(), Decimal(amount))
        labels.setdefault(key, description.strip())
        months_by_key[key].add((occurred_at.year, occurred_at.month))

    current = (month.year, month.month)
    recurring = [
        RecurringExpense(
            description=labels[key],
            amount=key[1],
            months_seen=len(months),
            pending_this_month=current not in months,
        )
        for key, months in months_by_key.items()
        if len(months) >= _RECURRING_MIN_MONTHS
    ]
    recurring.sort(key=lambda item: item.amount, reverse=True)
    return recurring


def _goals(db: Session, owner_id: uuid.UUID, today: date) -> list[GoalSnapshot]:
    balances = dict(
        db.execute(select(Account.id, Account.balance).where(Account.owner_id == owner_id)).all()
    )

    snapshots: list[GoalSnapshot] = []
    query = select(Goal).where(Goal.owner_id == owner_id).order_by(Goal.created_at)
    for goal in db.scalars(query):
        # A goal tied to an account follows that balance; the others follow
        # what the user put aside by hand.
        raw_saved = balances.get(goal.linked_account_id, goal.saved_amount)
        saved = max(Decimal(raw_saved or 0), ZERO)
        remaining = max(goal.target_amount - saved, ZERO)

        months_left: int | None = None
        monthly_needed: Decimal | None = None
        if goal.deadline is not None:
            months_left = max(
                (goal.deadline.year - today.year) * 12 + goal.deadline.month - today.month, 0
            )
            if months_left > 0:
                monthly_needed = (remaining / months_left).quantize(Decimal("0.01"))
            elif remaining > ZERO:
                monthly_needed = remaining

        progress = (
            float(min(saved / goal.target_amount, Decimal("1")) * 100)
            if goal.target_amount > ZERO
            else 0.0
        )
        snapshots.append(
            GoalSnapshot(
                title=goal.title,
                target_amount=goal.target_amount,
                saved_amount=saved,
                remaining=remaining,
                progress_percent=progress,
                deadline=goal.deadline,
                months_left=months_left,
                monthly_needed=monthly_needed,
            )
        )
    return snapshots


def _top_expenses(db: Session, owner_id: uuid.UUID, month: date) -> list[ExpenseSnapshot]:
    rows = db.execute(
        select(
            Transaction.description,
            Category.name,
            Transaction.amount,
            Transaction.occurred_at,
        )
        .select_from(Transaction)
        .join(Account, Account.id == Transaction.account_id)
        .outerjoin(Category, Category.id == Transaction.category_id)
        .where(
            Account.owner_id == owner_id,
            Transaction.type == TransactionType.EXPENSE,
            Transaction.occurred_at >= first_day_of_month(month),
            Transaction.occurred_at <= last_day_of_month(month),
        )
        .order_by(Transaction.amount.desc())
        .limit(_TOP_EXPENSES)
    ).all()

    return [
        ExpenseSnapshot(
            description=description,
            category_name=category_name or "Sem categoria",
            amount=Decimal(amount),
            occurred_at=occurred_at,
        )
        for description, category_name, amount, occurred_at in rows
    ]


def build_financial_context(
    db: Session, owner_id: uuid.UUID, today: date | None = None
) -> FinancialContext:
    reference = today or date.today()
    previous = previous_month(reference)

    accounts = list(db.scalars(select(Account).where(Account.owner_id == owner_id)))
    total_balance = sum((account.balance for account in accounts), ZERO)
    # A credit card holds what is owed, not what is held.
    liabilities = sum(
        (
            -account.balance
            for account in accounts
            if account.type == AccountType.CREDIT_CARD and account.balance < ZERO
        ),
        ZERO,
    )

    income = _month_total(db, owner_id, reference, TransactionType.INCOME)
    expenses = _month_total(db, owner_id, reference, TransactionType.EXPENSE)
    previous_expenses = _month_total(db, owner_id, previous, TransactionType.EXPENSE)

    current_categories = _category_totals(db, owner_id, reference)
    previous_categories = _category_totals(db, owner_id, previous)
    spending_by_category = sorted(
        (
            CategorySpend(
                name=name,
                total=total,
                share_of_expenses=float(total / expenses * 100) if expenses > ZERO else 0.0,
                previous_month_total=previous_categories.get(name),
                change_percent=_percent_change(previous_categories.get(name, ZERO), total),
            )
            for name, total in current_categories.items()
        ),
        key=lambda item: item.total,
        reverse=True,
    )

    budgets = [
        BudgetSnapshot(
            category_name=status.category_name,
            limit_amount=status.limit_amount,
            spent=status.spent,
            remaining=status.remaining,
            used_percent=(
                float(status.spent / status.limit_amount * 100)
                if status.limit_amount > ZERO
                else 0.0
            ),
        )
        for status in budgets_service.budget_status(db, owner_id, reference)
    ]

    transaction_count = db.scalar(
        select(func.count(Transaction.id))
        .select_from(Transaction)
        .join(Account, Account.id == Transaction.account_id)
        .where(Account.owner_id == owner_id)
    )

    return FinancialContext(
        as_of=reference,
        month_label=month_label(reference),
        days_left_in_month=(last_day_of_month(reference) - reference).days,
        total_balance=total_balance,
        month_income=income,
        month_expenses=expenses,
        month_net=income - expenses,
        savings_rate=float((income - expenses) / income * 100) if income > ZERO else None,
        previous_month_expenses=previous_expenses,
        transaction_count=transaction_count or 0,
        accounts=[
            AccountSnapshot(name=account.name, type=account.type.value, balance=account.balance)
            for account in accounts
        ],
        spending_by_category=spending_by_category,
        budgets=budgets,
        goals=_goals(db, owner_id, reference),
        recurring_expenses=_recurring_expenses(db, owner_id, reference),
        top_expenses=_top_expenses(db, owner_id, reference),
        investments=InvestmentSnapshot(
            available_to_invest=max(income - expenses, ZERO),
            reserve_months=float(total_balance / expenses) if expenses > ZERO else None,
        ),
        liabilities=liabilities,
    )
