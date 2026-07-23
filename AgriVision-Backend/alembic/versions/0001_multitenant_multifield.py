"""multi-tenant multi-field foundation

Revision ID: 0001_multitenant
Revises:
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from app.database import Base
from app.models import db_models  # noqa: F401

revision = "0001_multitenant"
down_revision = None
branch_labels = None
depends_on = None


def _columns(inspector, table):
    return {column["name"] for column in inspector.get_columns(table)}


def _add(table, name, column, inspector):
    if name not in _columns(inspector, table):
        op.add_column(table, column)


def _create_index(inspector, name, table, columns):
    existing = {index["name"] for index in inspector.get_indexes(table)}
    if name not in existing:
        op.create_index(name, table, columns)


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing = set(inspector.get_table_names())
    if "users" not in existing:
        Base.metadata.create_all(bind=bind)
        return

    _add("fields", "status", sa.Column("status", sa.String(20), nullable=False, server_default="active"), inspector)
    _add("fields", "archived_at", sa.Column("archived_at", sa.DateTime(timezone=True)), inspector)
    _add("fields", "updated_at", sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")), inspector)
    _add("fields", "agro_status", sa.Column("agro_status", sa.String(24), nullable=False, server_default="pending"), inspector)
    _add("fields", "agro_error", sa.Column("agro_error", sa.String(500)), inspector)
    _add("fields", "agro_retryable", sa.Column("agro_retryable", sa.Boolean(), nullable=False, server_default=sa.true()), inspector)
    bind.execute(sa.text("UPDATE fields SET area_ha = ST_Area(boundary::geography) / 10000.0 WHERE area_ha IS NULL"))
    op.alter_column("fields", "area_ha", existing_type=sa.Float(), nullable=False)

    _add("sensors", "owner_id", sa.Column("owner_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id")), inspector)
    bind.execute(sa.text("UPDATE sensors s SET owner_id = f.owner_id FROM fields f WHERE s.field_id = f.id AND s.owner_id IS NULL"))

    _add("field_recommendations", "analysis_run_id", sa.Column("analysis_run_id", postgresql.UUID(as_uuid=True)), inspector)
    _add("field_recommendations", "feedback_at", sa.Column("feedback_at", sa.DateTime(timezone=True)), inspector)

    new_tables = [
        "field_observations",
        "satellite_scenes",
        "ai_analysis_runs",
        "ai_chat_threads",
        "provider_capabilities",
        "provider_request_logs",
        "provider_cache",
    ]
    for name in new_tables:
        Base.metadata.tables[name].create(bind=bind, checkfirst=True)

    inspector = sa.inspect(bind)
    _add("ai_chat_messages", "thread_id", sa.Column("thread_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("ai_chat_threads.id", ondelete="CASCADE")), inspector)
    inspector = sa.inspect(bind)
    op.create_foreign_key("fk_recommendation_analysis_run", "field_recommendations", "ai_analysis_runs", ["analysis_run_id"], ["id"], ondelete="SET NULL")
    _create_index(inspector, "ix_fields_owner_status", "fields", ["owner_id", "status"])
    _create_index(inspector, "ix_sensors_owner_id", "sensors", ["owner_id"])
    _create_index(inspector, "ix_ai_chat_messages_thread_id", "ai_chat_messages", ["thread_id"])


def downgrade():
    raise RuntimeError("The AgriVision foundation migration is intentionally irreversible")
