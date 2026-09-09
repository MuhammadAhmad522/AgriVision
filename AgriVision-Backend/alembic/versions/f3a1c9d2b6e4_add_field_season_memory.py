"""Add field_season_memories table

Revision ID: f3a1c9d2b6e4
Revises: b7e1d4a9f312
Create Date: 2026-08-25 00:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = 'f3a1c9d2b6e4'
down_revision: Union[str, None] = 'b7e1d4a9f312'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'field_season_memories',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('field_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('fields.id', ondelete='CASCADE'), nullable=False),
        sa.Column('season_started_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('season_ended_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('narrative', sa.Text(), nullable=True),
        sa.Column('key_events', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default=sa.text("'[]'::jsonb")),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    )
    op.create_index('ix_field_season_memories_field_id', 'field_season_memories', ['field_id'])
    # Partial unique index: only one *active* (not yet ended) season per field.
    op.create_index(
        'uq_field_season_memories_active',
        'field_season_memories',
        ['field_id'],
        unique=True,
        postgresql_where=sa.text('season_ended_at IS NULL'),
    )
    # ### end Alembic commands ###


def downgrade() -> None:
    op.drop_index('uq_field_season_memories_active', table_name='field_season_memories')
    op.drop_index('ix_field_season_memories_field_id', table_name='field_season_memories')
    op.drop_table('field_season_memories')
    # ### end Alembic commands ###
