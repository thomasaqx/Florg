import uuid
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import NotFoundError

from app.modules.accounts import service as accounts_service
from app.modules.accounts.models import Account
from app.modules.categorization.engine import get_categorization_strategy
from app.modules.categorization.models import Category
from app.modules.transactions.models import Transaction, TransactionType
from app.modules.transactions.schemas import TransactionCreate, TransactionUpdate


def signed_amount(amount: Decimal, type_: TransactionType) -> Decimal:
    """Impact on the balance: income adds, expense subtracts."""
    return amount if type_ == TransactionType.INCOME else -amount


def _apply_to_balance(account: Account, amount: Decimal, type_: TransactionType) -> None:
    account.balance = account.balance + signed_amount(amount, type_)


def _revert_from_balance(account: Account, amount: Decimal, type_: TransactionType) -> None:
    account.balance = account.balance - signed_amount(amount, type_)


def list_transactions(db: Session, owner_id: uuid.UUID, account_id: uuid.UUID) -> list[Transaction]:
    # An account that is not the caller's reads as an empty statement rather
    # than a 404 -- a collection endpoint has a sane empty answer, and this
    # way it tells a stranger nothing about which ids exist.
    if accounts_service.get_owned_account(db, owner_id, account_id) is None:
        return []
    return list(
        db.scalars(
            select(Transaction)
            .where(Transaction.account_id == account_id)
            .order_by(Transaction.occurred_at.desc(), Transaction.created_at.desc())
        )
    )


def list_all_transactions(db: Session, owner_id: uuid.UUID) -> list[Transaction]:
    """Every transaction of the user, across all accounts.

    Avoids the N+1 the app used to do: one request per account.
    """
    return list(
        db.scalars(
            select(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .where(Account.owner_id == owner_id)
            .order_by(Transaction.occurred_at.desc(), Transaction.created_at.desc())
        )
    )


def get_owned_transaction(
    db: Session, owner_id: uuid.UUID, transaction_id: uuid.UUID
) -> Transaction:
    """Returns the transaction only if it belongs to an account of this user.

    Raises the same 404 for a transaction that does not exist and for one that
    belongs to someone else: telling them apart would confirm the id to
    whoever guessed it.
    """
    transaction = db.scalar(
        select(Transaction)
        .join(Account, Account.id == Transaction.account_id)
        .where(Transaction.id == transaction_id, Account.owner_id == owner_id)
    )
    if transaction is None:
        raise NotFoundError("Transacao nao encontrada")
    return transaction


def _resolve_category_id(db: Session, description: str) -> uuid.UUID | None:
    strategy = get_categorization_strategy()
    category_name = strategy.categorize(description)
    category = db.scalar(select(Category).where(Category.name == category_name))
    return category.id if category else None


def create_transaction(
    db: Session, owner_id: uuid.UUID, data: TransactionCreate
) -> Transaction:
    account = accounts_service.get_owned_account(db, owner_id, data.account_id)
    if account is None:
        raise NotFoundError("Conta nao encontrada")

    category_id = data.category_id or _resolve_category_id(db, data.description)

    transaction = Transaction(
        account_id=data.account_id,
        category_id=category_id,
        description=data.description,
        amount=data.amount,
        type=data.type,
        occurred_at=data.occurred_at,
    )
    db.add(transaction)
    _apply_to_balance(account, data.amount, data.type)

    db.commit()
    db.refresh(transaction)
    return transaction


def update_transaction(
    db: Session, owner_id: uuid.UUID, transaction_id: uuid.UUID, data: TransactionUpdate
) -> Transaction:
    transaction = get_owned_transaction(db, owner_id, transaction_id)

    origin_account = db.get(Account, transaction.account_id)
    if origin_account is None:
        raise NotFoundError("Conta de origem nao encontrada")

    target_account = origin_account
    if data.account_id is not None and data.account_id != transaction.account_id:
        moved_to = accounts_service.get_owned_account(db, owner_id, data.account_id)
        if moved_to is None:
            raise NotFoundError("Conta de destino nao encontrada")
        target_account = moved_to

    # Undo the old effect before applying the new one. Without this the balance
    # drifts on every edit -- the kind of bug that only surfaces weeks later.
    _revert_from_balance(origin_account, transaction.amount, transaction.type)

    if data.description is not None:
        transaction.description = data.description
    if data.amount is not None:
        transaction.amount = data.amount
    if data.type is not None:
        transaction.type = data.type
    if data.occurred_at is not None:
        transaction.occurred_at = data.occurred_at
    if data.category_id is not None:
        transaction.category_id = data.category_id
    transaction.account_id = target_account.id

    _apply_to_balance(target_account, transaction.amount, transaction.type)

    db.commit()
    db.refresh(transaction)
    return transaction


def delete_transaction(db: Session, owner_id: uuid.UUID, transaction_id: uuid.UUID) -> None:
    transaction = get_owned_transaction(db, owner_id, transaction_id)

    account = db.get(Account, transaction.account_id)
    if account is not None:
        _revert_from_balance(account, transaction.amount, transaction.type)

    db.delete(transaction)
    db.commit()
