"""store a private logo for each rental service unit"""
from alembic import op
import sqlalchemy as sa

revision = "gv2w3x4y5z6a"
down_revision = "gu1u2v3w4x5y"
branch_labels = None
depends_on = None

def upgrade():
    op.add_column("rental_companies", sa.Column("logo_file_url", sa.String(500), nullable=True))

def downgrade():
    op.drop_column("rental_companies", "logo_file_url")
