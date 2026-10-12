"""Add descriptions to parking extra services.

Revision ID: fq4d5e6f7a8b
Revises: fp3d4e5f6a7b
"""
from alembic import op
import sqlalchemy as sa

revision = "fq4d5e6f7a8b"
down_revision = "fp3d4e5f6a7b"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("parking_services", sa.Column("description", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("parking_services", "description")
