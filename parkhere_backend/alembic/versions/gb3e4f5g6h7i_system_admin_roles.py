"""Add scoped system administrator operator role."""
from alembic import op
import sqlalchemy as sa

revision = "gb3e4f5g6h7i"
down_revision = "ga2d3e4f5g6h"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "users", "role",
        existing_type=sa.Enum(
            "CUSTOMER", "PARTNER_MANAGER", "PARKING_ADMIN", "OPERATOR",
            "TOUR_GUIDE", "SUPER_ADMIN",
        ),
        type_=sa.Enum(
            "CUSTOMER", "PARTNER_MANAGER", "PARKING_ADMIN", "OPERATOR",
            "TOUR_GUIDE", "SUPER_ADMIN", "SYSTEM_ADMIN_OPERATOR",
        ),
        existing_nullable=False,
    )


def downgrade() -> None:
    op.execute("UPDATE users SET role='SUPER_ADMIN' WHERE role='SYSTEM_ADMIN_OPERATOR'")
    op.alter_column(
        "users", "role",
        existing_type=sa.Enum(
            "CUSTOMER", "PARTNER_MANAGER", "PARKING_ADMIN", "OPERATOR",
            "TOUR_GUIDE", "SUPER_ADMIN", "SYSTEM_ADMIN_OPERATOR",
        ),
        type_=sa.Enum(
            "CUSTOMER", "PARTNER_MANAGER", "PARKING_ADMIN", "OPERATOR",
            "TOUR_GUIDE", "SUPER_ADMIN",
        ),
        existing_nullable=False,
    )
