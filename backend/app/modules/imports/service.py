import hashlib
import uuid
from collections import Counter
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.modules.accounts import service as accounts_service
from app.modules.categorization.engine import get_categorization_strategy
from app.modules.categorization.models import Category
from app.modules.imports import parser
from app.modules.imports.models import ImportBatch
from app.modules.imports.schemas import (
    ColumnMapping,
    ImportCommit,
    ImportPreview,
    ImportResult,
    ImportRow,
    SkippedRow,
)
from app.modules.transactions.models import Transaction, TransactionType
from app.modules.transactions.service import signed_amount

MAX_DESCRIPTION = 200


def _fingerprint(occurred_at, description: str, amount: Decimal, type_: str, occurrence: int) -> str:
    """Stable id for a statement line, used to skip rows already imported.

    The occurrence counter is what makes two genuine R$ 5,00 coffees on the same
    day both import, while re-sending the same file imports neither twice.
    """
    raw = f"{occurred_at.isoformat()}|{description.strip().lower()}|{amount}|{type_}|{occurrence}"
    return "xlsx:" + hashlib.sha1(raw.encode("utf-8")).hexdigest()[:24]


def build_preview(filename: str, content: bytes, override: ColumnMapping | None) -> ImportPreview:
    """Parses the uploaded file without touching the database."""
    grid = parser.read_rows(filename, content)
    grid = [row for row in grid if not parser.is_blank(row)]
    if not grid:
        raise parser.SpreadsheetError("Não encontrei nenhuma linha preenchida no arquivo.")

    header_index = parser.find_header_row(grid)
    headers = [str(cell or "").strip() for cell in grid[header_index]]
    body = grid[header_index + 1 :]
    width = max((len(row) for row in grid), default=0)

    if override is not None and any(
        value is not None for value in (override.date, override.description, override.amount)
    ):
        mapping = override.model_dump()
    else:
        mapping = parser.detect_columns(headers)
        mapping = parser.infer_columns_by_content(
            body[: parser.SAMPLE_ROWS],
            mapping,
            width,
            excluded=parser.balance_columns(headers),
        )

    if mapping.get("date") is None or mapping.get("amount") is None:
        raise parser.SpreadsheetError(
            "Não identifiquei as colunas de data e valor. "
            "Confira se a planilha tem um cabeçalho com esses nomes."
        )

    rows: list[ImportRow] = []
    skipped: list[SkippedRow] = []
    seen: Counter[str] = Counter()

    for offset, raw_row in enumerate(body):
        line = header_index + offset + 2  # 1-based, and the header takes one line
        if len(rows) >= parser.MAX_ROWS:
            skipped.append(
                SkippedRow(
                    line=line,
                    reason=f"Limite de {parser.MAX_ROWS} linhas por arquivo",
                    raw=_as_text(raw_row),
                )
            )
            break

        occurred_at = parser.parse_date(parser.cell(raw_row, mapping["date"]))
        if occurred_at is None:
            skipped.append(
                SkippedRow(line=line, reason="Data em branco ou ilegível", raw=_as_text(raw_row))
            )
            continue

        amount = parser.parse_amount(parser.cell(raw_row, mapping["amount"]))
        if amount is None:
            skipped.append(
                SkippedRow(line=line, reason="Valor em branco ou ilegível", raw=_as_text(raw_row))
            )
            continue
        if amount == 0:
            skipped.append(SkippedRow(line=line, reason="Valor zerado", raw=_as_text(raw_row)))
            continue

        description = str(parser.cell(raw_row, mapping["description"]) or "").strip()
        if not description:
            description = "Lançamento sem descrição"
        description = description[:MAX_DESCRIPTION]

        declared = parser.parse_type(parser.cell(raw_row, mapping.get("type")))
        if declared is not None:
            type_ = TransactionType(declared)
        else:
            # No type column: the sign of the amount decides, which is how
            # almost every bank export is shaped.
            type_ = TransactionType.EXPENSE if amount < 0 else TransactionType.INCOME

        absolute = abs(amount)
        key = f"{occurred_at}|{description.lower()}|{absolute}|{type_.value}"
        seen[key] += 1

        rows.append(
            ImportRow(
                line=line,
                description=description,
                amount=absolute,
                type=type_,
                occurred_at=occurred_at,
                fingerprint=_fingerprint(
                    occurred_at, description, absolute, type_.value, seen[key]
                ),
            )
        )

    return ImportPreview(
        filename=filename,
        header_row=header_index,
        headers=headers,
        mapping=ColumnMapping(**mapping),
        total_rows=len(rows) + len(skipped),
        rows=rows,
        skipped=skipped,
        duplicate_count=0,
    )


def _as_text(row: list[object]) -> list[str]:
    return [str(cell) if cell is not None else "" for cell in row][:8]


def count_existing(db: Session, account_id: uuid.UUID, rows: list[ImportRow]) -> int:
    """How many of these rows are already in the account."""
    if not rows:
        return 0
    fingerprints = [row.fingerprint for row in rows]
    return len(
        set(
            db.scalars(
                select(Transaction.external_reference).where(
                    Transaction.account_id == account_id,
                    Transaction.external_reference.in_(fingerprints),
                )
            )
        )
    )


def _category_index(db: Session) -> dict[str, uuid.UUID]:
    return {category.name: category.id for category in db.scalars(select(Category))}


def commit(db: Session, owner_id: uuid.UUID, data: ImportCommit) -> ImportResult:
    """Writes the previewed rows as transactions."""
    account = accounts_service.get_owned_account(db, owner_id, data.account_id)
    if account is None:
        raise NotFoundError("Conta não encontrada")

    already_imported = set(
        db.scalars(
            select(Transaction.external_reference).where(
                Transaction.account_id == account.id,
                Transaction.external_reference.in_([row.fingerprint for row in data.rows]),
            )
        )
    )

    strategy = get_categorization_strategy()
    categories = _category_index(db)

    delta = Decimal("0")
    imported = 0
    duplicates = 0
    # Guards against a file that repeats a line inside itself after the preview
    # was edited by hand.
    used: set[str] = set()

    for row in data.rows:
        if row.fingerprint in already_imported or row.fingerprint in used:
            duplicates += 1
            continue
        used.add(row.fingerprint)

        db.add(
            Transaction(
                account_id=account.id,
                category_id=categories.get(strategy.categorize(row.description)),
                description=row.description,
                amount=row.amount,
                type=row.type,
                occurred_at=row.occurred_at,
                external_reference=row.fingerprint,
            )
        )
        delta += signed_amount(row.amount, row.type)
        imported += 1

    # One balance write for the whole file instead of one per row.
    account.balance = account.balance + delta

    batch = ImportBatch(
        account_id=account.id,
        filename=data.filename,
        rows_imported=imported,
        rows_duplicated=duplicates,
    )
    db.add(batch)

    db.commit()
    db.refresh(batch)
    db.refresh(account)

    return ImportResult(
        batch_id=batch.id,
        imported=imported,
        duplicates=duplicates,
        account_balance=account.balance,
    )


def list_batches(db: Session, owner_id: uuid.UUID) -> list[ImportBatch]:
    from app.modules.accounts.models import Account

    return list(
        db.scalars(
            select(ImportBatch)
            .join(Account, Account.id == ImportBatch.account_id)
            .where(Account.owner_id == owner_id)
            .order_by(ImportBatch.created_at.desc())
        )
    )
