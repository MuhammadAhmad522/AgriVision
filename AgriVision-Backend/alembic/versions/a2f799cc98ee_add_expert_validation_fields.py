"""Add expert validation fields

Revision ID: a2f799cc98ee
Revises: 42a5c0f83a43
Create Date: 2026-08-22 19:42:33.405469
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = 'a2f799cc98ee'
down_revision: Union[str, None] = '42a5c0f83a43'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('field_recommendations', sa.Column('expert_status', sa.String(length=20), server_default='pending', nullable=False))
    op.add_column('field_recommendations', sa.Column('expert_notes', sa.Text(), nullable=True))
    # ### end Alembic commands ###


def downgrade() -> None:
    op.drop_column('field_recommendations', 'expert_notes')
    op.drop_column('field_recommendations', 'expert_status')
    # ### end Alembic commands ###
