"""Add partner permission profiles and operator profile assignment."""
from alembic import op
import sqlalchemy as sa

revision = "ga2d3e4f5g6h"
down_revision = "fz1c2d3e4f5g"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "partner_permission_profiles",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        # MySQL does not allow defaults on TEXT columns; application code
        # supplies the empty JSON list for new profiles.
        sa.Column("permissions", sa.Text, nullable=False),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.true()),
        sa.UniqueConstraint("tenant_id", "name", name="uq_partner_permission_profile_name"),
    )
    op.add_column(
        "users",
        sa.Column("permission_profile_id", sa.String(36), sa.ForeignKey("partner_permission_profiles.id"), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "permission_profile_id")
    op.drop_table("partner_permission_profiles")
