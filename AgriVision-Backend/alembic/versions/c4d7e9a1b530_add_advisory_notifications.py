"""Add field-scoped, prioritised, attributable advisory notifications.

Notifications previously carried only a title and body with no sender, no field and no
severity. That was enough for the single "an agronomist reviewed something" message the
system produced, but not for an agronomist sending a farmer direct advice: the farmer
could not see who sent it, which field it concerned, or whether it was urgent.

Revision ID: c4d7e9a1b530
Revises: 9b1f4c6a2d8e
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

revision = 'c4d7e9a1b530'
down_revision = '9b1f4c6a2d8e'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('user_notifications', sa.Column('field_id', PG_UUID(as_uuid=True), nullable=True))
    op.add_column('user_notifications', sa.Column('created_by_id', PG_UUID(as_uuid=True), nullable=True))
    op.add_column(
        'user_notifications',
        sa.Column('priority', sa.String(length=20), nullable=False, server_default='normal'),
    )
    op.add_column(
        'user_notifications',
        sa.Column('category', sa.String(length=50), nullable=False, server_default='system'),
    )

    op.create_foreign_key(
        'fk_user_notifications_field_id', 'user_notifications', 'fields',
        ['field_id'], ['id'], ondelete='CASCADE',
    )
    # A deleted staff account must not delete the advice they gave the farmer.
    op.create_foreign_key(
        'fk_user_notifications_created_by_id', 'user_notifications', 'users',
        ['created_by_id'], ['id'], ondelete='SET NULL',
    )
    op.create_index('ix_user_notifications_field_id', 'user_notifications', ['field_id'])
    # The inbox query is always "this user's notifications, newest first".
    op.create_index(
        'ix_user_notifications_user_created', 'user_notifications', ['user_id', 'created_at'],
    )


def downgrade() -> None:
    op.drop_index('ix_user_notifications_user_created', table_name='user_notifications')
    op.drop_index('ix_user_notifications_field_id', table_name='user_notifications')
    op.drop_constraint('fk_user_notifications_created_by_id', 'user_notifications', type_='foreignkey')
    op.drop_constraint('fk_user_notifications_field_id', 'user_notifications', type_='foreignkey')
    op.drop_column('user_notifications', 'category')
    op.drop_column('user_notifications', 'priority')
    op.drop_column('user_notifications', 'created_by_id')
    op.drop_column('user_notifications', 'field_id')
