# Imports every model so Alembic and SQLAlchemy know about all tables.
from app.db.base import Base  # noqa: F401
from app.modules.accounts.models import Account  # noqa: F401
from app.modules.auth.models import User  # noqa: F401
from app.modules.budgets.models import Budget  # noqa: F401
from app.modules.categorization.models import Category  # noqa: F401
from app.modules.goals.models import Goal  # noqa: F401
from app.modules.imports.models import ImportBatch  # noqa: F401
from app.modules.transactions.models import Transaction  # noqa: F401
