"""add rental vehicle media and specifications

Revision ID: gm3n4o5p6q7r
Revises: gl2m3n4o5p6q
"""
from alembic import op
import sqlalchemy as sa

revision = "gm3n4o5p6q7r"
down_revision = "gl2m3n4o5p6q"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("rental_vehicles", sa.Column("photo_urls", sa.JSON(), nullable=True))
    op.add_column("rental_vehicles", sa.Column("specifications", sa.JSON(), nullable=True))


def downgrade():
    op.drop_column("rental_vehicles", "specifications")
    op.drop_column("rental_vehicles", "photo_urls")
