import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.accounts.models import Account
from app.modules.accounts.schemas import AccountCreate


def list_accounts(db: Session, owner_id: uuid.UUID) -> list[Account]:
    return list(db.scalars(select(Account).where(Account.owner_id == owner_id)))


def create_account(db: Session, owner_id: uuid.UUID, data: AccountCreate) -> Account:
    account = Account(owner_id=owner_id, name=data.name, type=data.type, balance=data.balance)
    db.add(account)
    db.commit()
    db.refresh(account)
    return account


def get_owned_account(db: Session, owner_id: uuid.UUID, account_id: uuid.UUID) -> Account | None:
    return db.scalar(select(Account).where(Account.id == account_id, Account.owner_id == owner_id))
