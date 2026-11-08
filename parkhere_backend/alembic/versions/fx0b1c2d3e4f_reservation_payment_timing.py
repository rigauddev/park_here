"""Track payment confirmation for hourly automatic checkout."""

from alembic import op
import sqlalchemy as sa

revision = "fx0b1c2d3e4f"
down_revision = "fw9a0b1c2d3e"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("reservations", sa.Column("payment_confirmed_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("reservations", "payment_confirmed_at")
