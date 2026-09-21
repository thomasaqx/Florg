from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.modules.accounts import service
from app.modules.accounts.schemas import AccountCreate, AccountRead
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.models import User

router = APIRouter(prefix="/accounts", tags=["accounts"])


@router.get("", response_model=list[AccountRead])
def list_my_accounts(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return service.list_accounts(db, current_user.id)


@router.post("", response_model=AccountRead, status_code=status.HTTP_201_CREATED)
def create_account(
    data: AccountCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return service.create_account(db, current_user.id, data)
