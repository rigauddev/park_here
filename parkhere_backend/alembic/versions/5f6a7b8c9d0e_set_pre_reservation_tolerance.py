"""Set the MVP pre-reservation tolerance to five minutes."""

from alembic import op
import sqlalchemy as sa

revision = "5f6a7b8c9d0e"
down_revision = "4e5f6a7b8c9d"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("UPDATE parkings SET arrival_tolerance_minutes = 5")
    op.alter_column(
        "parkings",
        "arrival_tolerance_minutes",
        existing_type=sa.Integer(),
        server_default="5",
    )


def downgrade() -> None:
    op.alter_column(
        "parkings",
        "arrival_tolerance_minutes",
        existing_type=sa.Integer(),
        server_default="15",
    )
