"""Use the ten-minute manual checkout window for existing reservations."""

from alembic import op
import sqlalchemy as sa

revision = "fy1b2c3d4e5f"
down_revision = "fx0b1c2d3e4f"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("UPDATE reservations SET checkout_grace_minutes = 10 WHERE checkout_grace_minutes = 15")
    op.alter_column(
        "reservations",
        "checkout_grace_minutes",
        existing_type=sa.Integer(),
        existing_nullable=False,
        server_default="10",
    )


def downgrade() -> None:
    op.alter_column(
        "reservations",
        "checkout_grace_minutes",
        existing_type=sa.Integer(),
        existing_nullable=False,
        server_default="15",
    )
