"""operator package requests

Revision ID: fb1e2f3a4b5c
Revises: fa0d1e2f3a4b
"""
from alembic import op
import sqlalchemy as sa

revision = "fb1e2f3a4b5c"
down_revision = "fa0d1e2f3a4b"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "operator_package_requests",
        sa.Column("id", sa.CHAR(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("tenant_id", sa.String(36), nullable=False),
        sa.Column("requested_by", sa.String(36), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("package_type", sa.String(20), nullable=False, server_default="individual"),
        sa.Column("amount", sa.Float(), nullable=False, server_default="0"),
        sa.Column("status", sa.String(24), nullable=False, server_default="pending_payment"),
        sa.Column("receipt_path", sa.Text(), nullable=True),
        sa.Column("reviewed_by", sa.String(36), nullable=True),
        sa.ForeignKeyConstraint(["tenant_id"], ["tenants.id"]),
        sa.ForeignKeyConstraint(["requested_by"], ["users.id"]),
        sa.ForeignKeyConstraint(["reviewed_by"], ["users.id"]),
    )
    op.create_index("ix_operator_package_requests_tenant_id", "operator_package_requests", ["tenant_id"])
    op.create_index("ix_operator_package_requests_status", "operator_package_requests", ["status"])


def downgrade():
    op.drop_table("operator_package_requests")
