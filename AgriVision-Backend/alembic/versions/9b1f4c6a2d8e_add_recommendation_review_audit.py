"""add recommendation review audit fields

Revision ID: 9b1f4c6a2d8e
Revises: 148cde3f118a
Create Date: 2026-09-07 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '9b1f4c6a2d8e'
down_revision: Union[str, None] = '148cde3f118a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Who approved/rejected a recommendation, and when — a chemical-intervention
    # recommendation with no reviewer of record has no audit trail.
    op.add_column(
        'field_recommendations',
        sa.Column('reviewed_by_id', postgresql.UUID(as_uuid=True), nullable=True),
    )
    op.add_column(
        'field_recommendations',
        sa.Column('reviewed_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_foreign_key(
        'fk_field_recommendations_reviewed_by_id_users',
        'field_recommendations', 'users',
        ['reviewed_by_id'], ['id'],
        ondelete='SET NULL',
    )


def downgrade() -> None:
    op.drop_constraint(
        'fk_field_recommendations_reviewed_by_id_users',
        'field_recommendations', type_='foreignkey',
    )
    op.drop_column('field_recommendations', 'reviewed_at')
    op.drop_column('field_recommendations', 'reviewed_by_id')
