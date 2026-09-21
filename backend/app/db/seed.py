from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.categorization.engine import KEYWORD_RULES
from app.modules.categorization.models import Category


def seed_default_categories(db: Session) -> None:
    """Ensures the default categories exist, without duplicating on re-runs."""
    existing_names = set(db.scalars(select(Category.name)))
    new_categories = [Category(name=name) for name in KEYWORD_RULES if name not in existing_names]
    if new_categories:
        db.add_all(new_categories)
        db.commit()
