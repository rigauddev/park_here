"""Add recurring paid-module terms and discounts."""

from alembic import op
import sqlalchemy as sa

revision = "fw9a0b1c2d3e"
down_revision = "fv8f9a0b1c2d"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("partner_feature_entitlements", sa.Column("payment_terms", sa.Text(), nullable=True))
    op.add_column("partner_feature_requests", sa.Column("payment_terms", sa.Text(), nullable=True))
    op.execute("UPDATE partner_feature_entitlements SET billing_period='monthly' WHERE billing_period='one_time'")
    op.execute("UPDATE partner_feature_requests SET billing_period='monthly' WHERE billing_period='one_time'")


def downgrade() -> None:
    op.drop_column("partner_feature_requests", "payment_terms")
    op.drop_column("partner_feature_entitlements", "payment_terms")
