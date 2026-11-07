"""Add billing modalities and proof review to paid feature requests.

Revision ID: fl1b2c3d4e5f
Revises: fk0a1b2c3d4e
"""
from alembic import op
import sqlalchemy as sa

revision = "fl1b2c3d4e5f"
down_revision = "fk0a1b2c3d4e"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("partner_feature_entitlements", sa.Column("billing_prices", sa.Text(), nullable=True))
    op.add_column("partner_feature_entitlements", sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("partner_feature_requests", sa.Column("payment_method", sa.String(length=20), nullable=False, server_default="pix"))
    op.add_column("partner_feature_requests", sa.Column("receipt_path", sa.Text(), nullable=True))
    op.alter_column(
        "partner_feature_requests",
        "status",
        existing_type=sa.String(length=30),
        server_default="pending_payment",
    )


def downgrade():
    op.alter_column(
        "partner_feature_requests",
        "status",
        existing_type=sa.String(length=30),
        server_default="pending_review",
    )
    op.drop_column("partner_feature_requests", "receipt_path")
    op.drop_column("partner_feature_requests", "payment_method")
    op.drop_column("partner_feature_entitlements", "expires_at")
    op.drop_column("partner_feature_entitlements", "billing_prices")
