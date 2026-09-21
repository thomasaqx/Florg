"""goals and budgets

Metas e tetos de gasto passam a viver no banco. Antes existiam apenas na
sessao do app: fechou o aplicativo, perdeu.

Revision ID: c7d3e2a41b85
Revises: b2c41f7a9d10
Create Date: 2026-09-21 12:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = 'c7d3e2a41b85'
down_revision: Union[str, None] = 'b2c41f7a9d10'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    goal_priority = sa.Enum('LOW', 'MEDIUM', 'HIGH', name='goal_priority')
    goal_priority.create(op.get_bind(), checkfirst=True)

    op.create_table(
        'goals',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('owner_id', sa.UUID(), nullable=False),
        sa.Column('title', sa.String(), nullable=False),
        sa.Column('description', sa.String(), nullable=True),
        sa.Column('target_amount', sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column('saved_amount', sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column('deadline', sa.Date(), nullable=True),
        sa.Column('priority', goal_priority, nullable=False),
        sa.Column('icon', sa.String(), nullable=True),
        sa.Column('linked_account_id', sa.UUID(), nullable=True),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('now()'),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(['owner_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['linked_account_id'], ['accounts.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_goals_owner_id'), 'goals', ['owner_id'])

    op.create_table(
        'budgets',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('owner_id', sa.UUID(), nullable=False),
        sa.Column('category_id', sa.UUID(), nullable=False),
        sa.Column('month', sa.Date(), nullable=False),
        sa.Column('limit_amount', sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('now()'),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(['owner_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['category_id'], ['categories.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        # One ceiling per category per month: without this the app could show
        # two different limits for the same category.
        sa.UniqueConstraint(
            'owner_id', 'category_id', 'month', name='uq_budget_owner_category_month'
        ),
    )
    op.create_index(op.f('ix_budgets_owner_id'), 'budgets', ['owner_id'])


def downgrade() -> None:
    op.drop_index(op.f('ix_budgets_owner_id'), table_name='budgets')
    op.drop_table('budgets')
    op.drop_index(op.f('ix_goals_owner_id'), table_name='goals')
    op.drop_table('goals')
    sa.Enum(name='goal_priority').drop(op.get_bind(), checkfirst=True)
