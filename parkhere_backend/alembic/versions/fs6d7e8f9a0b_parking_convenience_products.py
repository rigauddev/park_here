"""Add convenience products sold by parking units."""
from alembic import op
import sqlalchemy as sa

revision = "fs6d7e8f9a0b"
down_revision = "fr5e6f7a8b9c"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "parking_convenience_products",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("parking_id", sa.String(36), sa.ForeignKey("parkings.id"), nullable=False),
        sa.Column("category", sa.String(80), nullable=False),
        sa.Column("subcategory", sa.String(80), nullable=True),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("price", sa.Float(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
    )


def downgrade() -> None:
    op.drop_table("parking_convenience_products")
