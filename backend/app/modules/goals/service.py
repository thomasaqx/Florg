import uuid
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import NotFoundError, ValidationError
from app.modules.accounts import service as accounts_service
from app.modules.goals.models import Goal
from app.modules.goals.schemas import GoalCreate, GoalUpdate

_UNSET = object()


def list_goals(db: Session, owner_id: uuid.UUID) -> list[Goal]:
    return list(
        db.scalars(
            select(Goal).where(Goal.owner_id == owner_id).order_by(Goal.created_at.asc())
        )
    )


def get_owned_goal(db: Session, owner_id: uuid.UUID, goal_id: uuid.UUID) -> Goal:
    """Returns the goal or raises. 404 for someone else's goal as well: an
    answer that distinguished "does not exist" from "not yours" would confirm
    the id exists to whoever guessed it."""
    goal = db.scalar(select(Goal).where(Goal.id == goal_id, Goal.owner_id == owner_id))
    if goal is None:
        raise NotFoundError("Meta não encontrada")
    return goal


def _validate_linked_account(
    db: Session, owner_id: uuid.UUID, account_id: uuid.UUID | None
) -> None:
    if account_id is None:
        return
    if accounts_service.get_owned_account(db, owner_id, account_id) is None:
        raise NotFoundError("Conta vinculada não encontrada")


def create_goal(db: Session, owner_id: uuid.UUID, data: GoalCreate) -> Goal:
    _validate_linked_account(db, owner_id, data.linked_account_id)

    goal = Goal(owner_id=owner_id, **data.model_dump())
    db.add(goal)
    db.commit()
    db.refresh(goal)
    return goal


def update_goal(
    db: Session, owner_id: uuid.UUID, goal_id: uuid.UUID, data: GoalUpdate
) -> Goal:
    goal = get_owned_goal(db, owner_id, goal_id)
    changes = data.model_dump(exclude_unset=True)

    if "linked_account_id" in changes:
        _validate_linked_account(db, owner_id, changes["linked_account_id"])

    for field, value in changes.items():
        setattr(goal, field, value)

    db.commit()
    db.refresh(goal)
    return goal


def contribute(
    db: Session, owner_id: uuid.UUID, goal_id: uuid.UUID, amount: Decimal
) -> Goal:
    goal = get_owned_goal(db, owner_id, goal_id)
    updated = goal.saved_amount + amount
    if updated < 0:
        raise ValidationError("A contribuição deixaria a meta com valor guardado negativo")

    goal.saved_amount = updated
    db.commit()
    db.refresh(goal)
    return goal


def delete_goal(db: Session, owner_id: uuid.UUID, goal_id: uuid.UUID) -> None:
    goal = get_owned_goal(db, owner_id, goal_id)
    db.delete(goal)
    db.commit()
