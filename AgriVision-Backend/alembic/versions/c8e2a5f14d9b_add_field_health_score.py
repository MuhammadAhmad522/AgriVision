"""Add AI-computed field health score columns

Revision ID: c8e2a5f14d9b
Revises: f3a1c9d2b6e4
Create Date: 2026-08-25 00:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'c8e2a5f14d9b'
down_revision: Union[str, None] = 'f3a1c9d2b6e4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('fields', sa.Column('latest_health_score', sa.Float(), nullable=True))
    op.add_column('fields', sa.Column('latest_health_label', sa.String(length=20), nullable=True))
    op.add_column('fields', sa.Column('latest_health_rationale', sa.Text(), nullable=True))
    op.add_column('fields', sa.Column('latest_health_updated_at', sa.DateTime(timezone=True), nullable=True))
    # ### end Alembic commands ###


def downgrade() -> None:
    op.drop_column('fields', 'latest_health_updated_at')
    op.drop_column('fields', 'latest_health_rationale')
    op.drop_column('fields', 'latest_health_label')
    op.drop_column('fields', 'latest_health_score')
    # ### end Alembic commands ###
