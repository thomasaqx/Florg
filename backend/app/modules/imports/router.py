import json
import uuid

from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.core.errors import NotFoundError, ValidationError as DomainValidationError
from app.db.session import get_db
from app.modules.accounts import service as accounts_service
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.models import User
from app.modules.imports import service
from app.modules.imports.parser import SpreadsheetError
from app.modules.imports.schemas import (
    ColumnMapping,
    ImportBatchRead,
    ImportCommit,
    ImportPreview,
    ImportResult,
)

router = APIRouter(prefix="/imports", tags=["imports"])


@router.post("/preview", response_model=ImportPreview)
async def preview_spreadsheet(
    file: UploadFile = File(...),
    account_id: uuid.UUID | None = Form(default=None),
    mapping: str | None = Form(
        default=None,
        description='Correção manual das colunas, como {"date":0,"description":1,"amount":2}',
    ),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Reads the file and returns the rows it found, without saving anything.

    Nothing is stored server-side between preview and commit: the app sends the
    reviewed rows back to POST /imports/commit.
    """
    override: ColumnMapping | None = None
    if mapping:
        try:
            override = ColumnMapping(**json.loads(mapping))
        except (json.JSONDecodeError, TypeError, ValidationError) as error:
            raise DomainValidationError("Mapeamento de colunas inválido.") from error

    content = await file.read()
    try:
        preview = service.build_preview(file.filename or "planilha", content, override)
    except SpreadsheetError as error:
        raise DomainValidationError(str(error)) from error

    # Knowing up front how many rows are already there is what stops the user
    # from importing the same statement twice by accident.
    if account_id is not None:
        account = accounts_service.get_owned_account(db, current_user.id, account_id)
        if account is None:
            raise NotFoundError("Conta não encontrada")
        preview.duplicate_count = service.count_existing(db, account.id, preview.rows)

    return preview


@router.post("/commit", response_model=ImportResult, status_code=status.HTTP_201_CREATED)
def commit_import(
    data: ImportCommit,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return service.commit(db, current_user.id, data)


@router.get("", response_model=list[ImportBatchRead])
def list_my_imports(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return service.list_batches(db, current_user.id)
