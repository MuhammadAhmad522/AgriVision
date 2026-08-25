"""Add recommendation evidence column and chat thread channel

Revision ID: b7e1d4a9f312
Revises: a2f799cc98ee
Create Date: 2026-08-25 00:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = 'b7e1d4a9f312'
down_revision: Union[str, None] = 'a2f799cc98ee'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('field_recommendations', sa.Column('evidence', postgresql.JSONB(astext_type=sa.Text()), nullable=True))

    op.add_column('ai_chat_threads', sa.Column('channel', sa.String(length=20), server_default='farmer', nullable=False))
    # The original single-column uniqueness on field_id was created as a unique INDEX
    # (Column(unique=True, index=True)), not a table-level UNIQUE constraint.
    op.drop_index('ix_ai_chat_threads_field_id', table_name='ai_chat_threads')
    op.create_unique_constraint('uq_ai_chat_thread_field_channel', 'ai_chat_threads', ['field_id', 'channel'])
    op.create_index('ix_ai_chat_threads_field_id', 'ai_chat_threads', ['field_id'])
    # ### end Alembic commands ###


def downgrade() -> None:
    op.drop_index('ix_ai_chat_threads_field_id', table_name='ai_chat_threads')
    op.drop_constraint('uq_ai_chat_thread_field_channel', 'ai_chat_threads', type_='unique')
    op.create_index('ix_ai_chat_threads_field_id', 'ai_chat_threads', ['field_id'], unique=True)
    op.drop_column('ai_chat_threads', 'channel')

    op.drop_column('field_recommendations', 'evidence')
    # ### end Alembic commands ###
