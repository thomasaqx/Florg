"""import_batches

Revision ID: b2c41f7a9d10
Revises: 96eaa1def4aa
Create Date: 2026-09-15 10:12:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'b2c41f7a9d10'
down_revision: Union[str, None] = '96eaa1def4aa'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'import_batches',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('account_id', sa.UUID(), nullable=False),
        sa.Column('filename', sa.String(), nullable=False),
        sa.Column('rows_imported', sa.Integer(), nullable=False),
        sa.Column('rows_duplicated', sa.Integer(), nullable=False),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('now()'),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(['account_id'], ['accounts.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    # Every import checks this column to skip rows it already wrote.
    op.create_index(
        'ix_transactions_account_external_ref',
        'transactions',
        ['account_id', 'external_reference'],
    )


def downgrade() -> None:
    op.drop_index('ix_transactions_account_external_ref', table_name='transactions')
    op.drop_table('import_batches')
