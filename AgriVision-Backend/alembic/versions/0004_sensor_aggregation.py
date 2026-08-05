"""create sensor_readings_hourly table for temporal aggregation

Revision ID: 0004_sensor_aggregation
Revises: 0003_reconcile
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "0004_sensor_aggregation"
down_revision = "0003_reconcile"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "sensor_readings_hourly",
        sa.Column("bucket", sa.DateTime(timezone=True), nullable=False),
        sa.Column("sensor_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("temperature_avg", sa.Float(), nullable=True),
        sa.Column("temperature_min", sa.Float(), nullable=True),
        sa.Column("temperature_max", sa.Float(), nullable=True),
        sa.Column("moisture_avg", sa.Float(), nullable=True),
        sa.Column("moisture_min", sa.Float(), nullable=True),
        sa.Column("moisture_max", sa.Float(), nullable=True),
        sa.Column("humidity_avg", sa.Float(), nullable=True),
        sa.Column("humidity_min", sa.Float(), nullable=True),
        sa.Column("humidity_max", sa.Float(), nullable=True),
        sa.Column("ph_avg", sa.Float(), nullable=True),
        sa.Column("ph_min", sa.Float(), nullable=True),
        sa.Column("ph_max", sa.Float(), nullable=True),
        sa.Column("ec_avg", sa.Float(), nullable=True),
        sa.Column("ec_min", sa.Float(), nullable=True),
        sa.Column("ec_max", sa.Float(), nullable=True),
        sa.Column("npk_n_avg", sa.Float(), nullable=True),
        sa.Column("npk_n_min", sa.Float(), nullable=True),
        sa.Column("npk_n_max", sa.Float(), nullable=True),
        sa.Column("npk_p_avg", sa.Float(), nullable=True),
        sa.Column("npk_p_min", sa.Float(), nullable=True),
        sa.Column("npk_p_max", sa.Float(), nullable=True),
        sa.Column("npk_k_avg", sa.Float(), nullable=True),
        sa.Column("npk_k_min", sa.Float(), nullable=True),
        sa.Column("npk_k_max", sa.Float(), nullable=True),
        sa.Column("reading_count", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["sensor_id"], ["sensors.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("bucket", "sensor_id"),
    )
    op.create_index("ix_sensor_readings_hourly_bucket", "sensor_readings_hourly", ["bucket"])
    op.create_index("ix_sensor_readings_hourly_sensor_id", "sensor_readings_hourly", ["sensor_id"])


def downgrade():
    op.drop_table("sensor_readings_hourly")
