"""Add users.display_name for showing farmer/staff names instead of raw emails

Revision ID: d5b8f1a3c7e2
Revises: c4d7e9a1b530
Create Date: 2026-09-08 06:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'd5b8f1a3c7e2'
down_revision: Union[str, None] = 'c4d7e9a1b530'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('users', sa.Column('display_name', sa.String(length=255), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'display_name')
