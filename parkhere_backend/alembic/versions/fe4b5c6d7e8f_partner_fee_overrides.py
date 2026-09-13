"""partner-specific platform fee overrides
Revision ID: fe4b5c6d7e8f
Revises: fd3a4b5c6d7e
"""
from alembic import op
import sqlalchemy as sa

revision = "fe4b5c6d7e8f"
down_revision = "fd3a4b5c6d7e"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "partner_platform_fees",
        sa.Column("id", sa.CHAR(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("service_type", sa.String(50), nullable=False),
        sa.Column("fee_mode", sa.String(20), nullable=False, server_default="hybrid"),
        sa.Column("fixed_amount", sa.Float(), nullable=False, server_default="0"),
        sa.Column("percentage", sa.Float(), nullable=False, server_default="0"),
        sa.Column("min_fee", sa.Float(), nullable=False, server_default="0"),
        sa.Column("max_fee", sa.Float(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.UniqueConstraint("tenant_id", "service_type", name="uq_partner_fee_tenant_service"),
    )
    op.create_index("ix_partner_platform_fees_tenant_id", "partner_platform_fees", ["tenant_id"])


def downgrade():
    op.drop_table("partner_platform_fees")
