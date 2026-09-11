"""add parking operating hours

Revision ID: fa0d1e2f3a4b
Revises: f9c0d1e2f3a4
"""
from alembic import op
import sqlalchemy as sa
revision = "fa0d1e2f3a4b"
down_revision = "f9c0d1e2f3a4"
branch_labels = None
depends_on = None

def upgrade():
    op.add_column("parkings", sa.Column("operating_hours", sa.Text(), nullable=True))

def downgrade():
    op.drop_column("parkings", "operating_hours")
