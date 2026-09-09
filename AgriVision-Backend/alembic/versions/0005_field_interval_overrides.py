"""Add interval_overrides JSONB column to fields table

Revision ID: 0005
Revises: 0004
Create Date: 2026-07-26

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

revision = "0005"
down_revision = "0004_sensor_aggregation"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = [col["name"] for col in inspector.get_columns("fields")]
    if "interval_overrides" not in columns:
        op.add_column("fields", sa.Column("interval_overrides", JSONB, nullable=False, server_default=sa.text("'{}'::jsonb")))


def downgrade() -> None:
    op.drop_column("fields", "interval_overrides")
