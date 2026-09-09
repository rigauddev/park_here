"""add parking special spot counts

Revision ID: 2c3d4e5f6a7b
Revises: 1b2c3d4e5f6a
Create Date: 2026-08-17 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "2c3d4e5f6a7b"
down_revision = "1b2c3d4e5f6a"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "parkings",
        sa.Column("vip_spots", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parkings",
        sa.Column("large_spots", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parkings",
        sa.Column("bus_spots", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parkings",
        sa.Column("pickup_spots", sa.Integer(), nullable=False, server_default="0"),
    )


def downgrade():
    op.drop_column("parkings", "pickup_spots")
    op.drop_column("parkings", "bus_spots")
    op.drop_column("parkings", "large_spots")
    op.drop_column("parkings", "vip_spots")
