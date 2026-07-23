"""status, hard deletion, multimodal chat, and AI evidence

Revision ID: 0002_multimodal_ai
Revises: 0001_multitenant
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "0002_multimodal_ai"
down_revision = "0001_multitenant"
branch_labels = None
depends_on = None


def _has_table(name):
    return name in sa.inspect(op.get_bind()).get_table_names()


def _has_column(table, name):
    return name in {column["name"] for column in sa.inspect(op.get_bind()).get_columns(table)}


def _add_column(table, column):
    if not _has_column(table, column.name):
        op.add_column(table, column)


def _create_index(name, table, columns):
    if name not in {index["name"] for index in sa.inspect(op.get_bind()).get_indexes(table)}:
        op.create_index(name, table, columns)


def _has_unique(table, name):
    return name in {constraint["name"] for constraint in sa.inspect(op.get_bind()).get_unique_constraints(table)}


def _ensure_cascade_fk(table, name):
    inspector = sa.inspect(op.get_bind())
    foreign_keys = inspector.get_foreign_keys(table)
    current = next((value for value in foreign_keys if value["name"] == name), None)
    if current and str((current.get("options") or {}).get("ondelete", "")).upper() == "CASCADE":
        return
    if current:
        op.drop_constraint(name, table, type_="foreignkey")
    op.create_foreign_key(name, table, "fields", ["field_id"], ["id"], ondelete="CASCADE")


def upgrade():
    _add_column("ai_analysis_runs", sa.Column("context_fingerprint", sa.String(64)))
    _add_column("ai_analysis_runs", sa.Column("model_name", sa.String(100)))
    _add_column("ai_analysis_runs", sa.Column("prompt_version", sa.String(40)))
    _add_column("ai_analysis_runs", sa.Column("policy_version", sa.String(40)))
    _add_column("ai_analysis_runs", sa.Column("data_quality", sa.String(20)))
    _add_column("ai_analysis_runs", sa.Column("evidence", postgresql.JSONB()))
    _create_index("ix_ai_analysis_runs_context_fingerprint", "ai_analysis_runs", ["context_fingerprint"])

    _add_column("field_recommendations", sa.Column("rationale", sa.Text()))
    _add_column("field_recommendations", sa.Column("confidence_reason", sa.String(500)))
    _add_column("field_recommendations", sa.Column("evidence", postgresql.JSONB()))
    _add_column("field_recommendations", sa.Column("safety_level", sa.String(20), nullable=False, server_default="guarded"))
    _add_column("field_recommendations", sa.Column("requires_expert_confirmation", sa.Boolean(), nullable=False, server_default=sa.false()))
    _add_column("field_recommendations", sa.Column("expires_at", sa.DateTime(timezone=True)))
    _add_column("field_recommendations", sa.Column("outcome", sa.String(20)))
    _add_column("field_recommendations", sa.Column("outcome_notes", sa.Text()))
    _add_column("field_recommendations", sa.Column("outcome_at", sa.DateTime(timezone=True)))

    _add_column("ai_chat_messages", sa.Column("idempotency_key", sa.String(100)))
    _add_column("ai_chat_messages", sa.Column("status", sa.String(20), nullable=False, server_default="completed"))
    _add_column("ai_chat_messages", sa.Column("reply_to_message_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("ai_chat_messages.id", ondelete="CASCADE")))
    _create_index("ix_ai_chat_messages_idempotency_key", "ai_chat_messages", ["idempotency_key"])
    _create_index("ix_ai_chat_messages_reply_to_message_id", "ai_chat_messages", ["reply_to_message_id"])
    if not _has_unique("ai_chat_messages", "uq_chat_message_field_idempotency"):
        op.create_unique_constraint("uq_chat_message_field_idempotency", "ai_chat_messages", ["field_id", "idempotency_key"])

    if not _has_table("chat_attachments"):
        op.create_table(
        "chat_attachments",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("field_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("fields.id", ondelete="CASCADE"), nullable=False),
        sa.Column("message_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("ai_chat_messages.id", ondelete="CASCADE"), nullable=False),
        sa.Column("storage_key", sa.String(500), nullable=False, unique=True),
        sa.Column("mime_type", sa.String(50), nullable=False),
        sa.Column("byte_size", sa.Integer(), nullable=False),
        sa.Column("width", sa.Integer(), nullable=False),
        sa.Column("height", sa.Integer(), nullable=False),
        sa.Column("sha256", sa.String(64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        )
    _create_index("ix_chat_attachments_field_id", "chat_attachments", ["field_id"])
    _create_index("ix_chat_attachments_message_id", "chat_attachments", ["message_id"])

    _ensure_cascade_fk("provider_request_logs", "provider_request_logs_field_id_fkey")
    _ensure_cascade_fk("provider_cache", "provider_cache_field_id_fkey")

    if not _has_table("field_deletion_jobs"):
        op.create_table(
        "field_deletion_jobs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("field_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("provider_polygon_id", sa.String(64)),
        sa.Column("media_paths", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_error", sa.String(500)),
        sa.Column("next_attempt_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
        )
    _create_index("ix_field_deletion_jobs_field_id", "field_deletion_jobs", ["field_id"])
    _create_index("ix_field_deletion_jobs_status", "field_deletion_jobs", ["status"])
    _create_index("ix_field_deletion_jobs_next_attempt_at", "field_deletion_jobs", ["next_attempt_at"])

    if not _has_table("agronomy_knowledge_documents"):
        op.create_table(
        "agronomy_knowledge_documents",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("external_id", sa.String(160), nullable=False, unique=True),
        sa.Column("title", sa.String(300), nullable=False),
        sa.Column("source_url", sa.String(1000), nullable=False),
        sa.Column("crop", sa.String(80), nullable=False),
        sa.Column("region", sa.String(100), nullable=False, server_default="Punjab, Pakistan"),
        sa.Column("version", sa.String(80)),
        sa.Column("published_at", sa.DateTime(timezone=True)),
        sa.Column("approved", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        )
    _create_index("ix_agronomy_knowledge_documents_crop", "agronomy_knowledge_documents", ["crop"])
    _create_index("ix_agronomy_knowledge_documents_region", "agronomy_knowledge_documents", ["region"])
    _create_index("ix_agronomy_knowledge_documents_approved", "agronomy_knowledge_documents", ["approved"])
    # Metadata seeds are deliberately unapproved until the corresponding documents are
    # reviewed and ingested into the private Vertex Search corpus.
    op.execute(sa.text("""
        INSERT INTO agronomy_knowledge_documents
            (id, external_id, title, source_url, crop, region, version, approved)
        VALUES
            ('b28b4bc5-7282-4e98-8644-939a5f54cb31', 'punjab-wheat-aari', 'Wheat Research Institute, Faisalabad', 'https://agripunjab.gov.pk/aari-inst-Wheat', 'wheat', 'Punjab, Pakistan', 'initial', false),
            ('4d4f4dc8-13fc-4e8a-a814-cfc4588545e9', 'punjab-rice-aari', 'Rice Research Institute, Kala Shah Kaku', 'https://agripunjab.gov.pk/aari-inst-Rice', 'rice', 'Punjab, Pakistan', 'initial', false),
            ('42bbbd45-d55f-4f36-9068-ff679432128c', 'punjab-sugarcane-aari', 'Sugarcane Research Institute, Faisalabad', 'https://agripunjab.gov.pk/aari-inst-Sugarcane', 'sugarcane', 'Punjab, Pakistan', 'initial', false)
        ON CONFLICT (external_id) DO NOTHING
    """))


def downgrade():
    raise RuntimeError("This data-protection migration is intentionally irreversible")
