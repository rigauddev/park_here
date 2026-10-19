"""Add optional stock control to convenience products."""

from alembic import op
import sqlalchemy as sa

revision = "fv8f9a0b1c2d"
down_revision = "fu8f9a0b1c2d"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("parking_convenience_products", sa.Column("stock_quantity", sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column("parking_convenience_products", "stock_quantity")
