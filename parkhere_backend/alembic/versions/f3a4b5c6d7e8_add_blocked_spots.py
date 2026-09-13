"""add persistent blocked parking spots"""
from alembic import op
import sqlalchemy as sa

revision = "f3a4b5c6d7e8"
down_revision = "f2a3b4c5d6e7"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("parkings", sa.Column("blocked_spots", sa.Text(), nullable=True))


def downgrade():
    op.drop_column("parkings", "blocked_spots")
