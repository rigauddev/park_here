"""Make permission profiles reusable for partner and platform administration."""
from alembic import op
import sqlalchemy as sa

revision = "gc4f5g6h7i8j"
down_revision = "gb3e4f5g6h7i"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "partner_permission_profiles", "tenant_id",
        existing_type=sa.String(36), existing_nullable=False, nullable=True,
    )
    op.add_column(
        "partner_permission_profiles",
        sa.Column("scope", sa.String(20), nullable=False, server_default="partner"),
    )


def downgrade() -> None:
    op.drop_column("partner_permission_profiles", "scope")
    op.alter_column(
        "partner_permission_profiles", "tenant_id",
        existing_type=sa.String(36), existing_nullable=True, nullable=False,
    )
