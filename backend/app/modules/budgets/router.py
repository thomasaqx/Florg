import uuid
from datetime import date

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.models import User
from app.modules.budgets import service
from app.modules.budgets.schemas import BudgetRead, BudgetStatus, BudgetUpsert

router = APIRouter(prefix="/budgets", tags=["budgets"])

_MONTH_QUERY = Query(default=None, description="Qualquer dia do mês desejado")


@router.get("", response_model=list[BudgetRead])
def list_my_budgets(
    month: date | None = _MONTH_QUERY,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return service.list_budgets(db, current_user.id, month)


@router.get("/status", response_model=list[BudgetStatus])
def budget_status(
    month: date = Query(default_factory=date.today, description="Qualquer dia do mês desejado"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Ceiling versus spending, computed in the database."""
    return service.budget_status(db, current_user.id, month)


@router.put("", response_model=BudgetRead)
def set_budget(
    data: BudgetUpsert,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return service.upsert_budget(db, current_user.id, data)


@router.delete("/{budget_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_budget(
    budget_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service.delete_budget(db, current_user.id, budget_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
