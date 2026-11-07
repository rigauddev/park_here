"""Persist separated parking address fields.

Revision ID: fp3d4e5f6a7b
Revises: fo2c3d4e5f6a
"""

from alembic import op
import sqlalchemy as sa


revision = "fp3d4e5f6a7b"
down_revision = "fo2c3d4e5f6a"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("parkings", sa.Column("street", sa.String(length=180), nullable=True))
    op.add_column("parkings", sa.Column("number", sa.String(length=30), nullable=True))
    op.add_column("parkings", sa.Column("neighborhood", sa.String(length=120), nullable=True))
    op.add_column("parkings", sa.Column("postal_code", sa.String(length=9), nullable=True))


def downgrade() -> None:
    op.drop_column("parkings", "postal_code")
    op.drop_column("parkings", "neighborhood")
    op.drop_column("parkings", "number")
    op.drop_column("parkings", "street")
