from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.models import User
from app.modules.insights import service
from app.modules.insights.schemas import CategorySummary, DashboardSummary

router = APIRouter(prefix="/insights", tags=["insights"])


@router.get("/spending-by-category", response_model=list[CategorySummary])
def spending_by_category(
    month: date = Query(default_factory=date.today, description="Qualquer dia do mês desejado"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return service.spending_by_category(db, current_user.id, month)


@router.get("/dashboard", response_model=DashboardSummary)
def dashboard(
    month: date = Query(default_factory=date.today, description="Qualquer dia do mes desejado"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return service.dashboard_summary(db, current_user.id, month)
