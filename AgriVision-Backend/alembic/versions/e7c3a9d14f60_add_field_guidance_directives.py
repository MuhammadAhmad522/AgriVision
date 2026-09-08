"""Add field_guidance_directives — durable agronomist standing guidance

Revision ID: e7c3a9d14f60
Revises: d5b8f1a3c7e2
Create Date: 2026-09-08 07:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID


revision: str = 'e7c3a9d14f60'
down_revision: Union[str, None] = 'd5b8f1a3c7e2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'field_guidance_directives',
        sa.Column('id', UUID(as_uuid=True), primary_key=True),
        sa.Column('field_id', UUID(as_uuid=True), sa.ForeignKey('fields.id', ondelete='CASCADE'), nullable=False),
        sa.Column('text', sa.Text(), nullable=False),
        sa.Column('status', sa.String(length=24), nullable=False, server_default='active'),
        sa.Column('created_by_id', UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('retracted_by_id', UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('retracted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('applied_run_id', UUID(as_uuid=True), sa.ForeignKey('ai_analysis_runs.id', ondelete='SET NULL'), nullable=True),
    )
    op.create_index('ix_field_guidance_directives_field_id', 'field_guidance_directives', ['field_id'])
    op.create_index('ix_field_guidance_directives_status', 'field_guidance_directives', ['status'])


def downgrade() -> None:
    op.drop_index('ix_field_guidance_directives_status', table_name='field_guidance_directives')
    op.drop_index('ix_field_guidance_directives_field_id', table_name='field_guidance_directives')
    op.drop_table('field_guidance_directives')
