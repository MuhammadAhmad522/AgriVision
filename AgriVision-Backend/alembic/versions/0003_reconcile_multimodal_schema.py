"""reconcile databases that ran an early 0002 revision

Revision ID: 0003_reconcile
Revises: 0002_multimodal_ai
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "0003_reconcile"
down_revision = "0002_multimodal_ai"
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = {column["name"] for column in inspector.get_columns("ai_chat_messages")}
    if "reply_to_message_id" not in columns:
        op.add_column("ai_chat_messages", sa.Column("reply_to_message_id", postgresql.UUID(as_uuid=True)))
        op.create_foreign_key(
            "fk_ai_chat_messages_reply_to_message_id",
            "ai_chat_messages",
            "ai_chat_messages",
            ["reply_to_message_id"],
            ["id"],
            ondelete="CASCADE",
        )
    indexes = {index["name"] for index in sa.inspect(bind).get_indexes("ai_chat_messages")}
    if "ix_ai_chat_messages_reply_to_message_id" not in indexes:
        op.create_index("ix_ai_chat_messages_reply_to_message_id", "ai_chat_messages", ["reply_to_message_id"])


def downgrade():
    raise RuntimeError("This data-protection migration is intentionally irreversible")
