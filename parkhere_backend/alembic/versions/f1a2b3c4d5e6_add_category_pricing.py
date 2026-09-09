"""store independent prices for every parking category"""
from alembic import op
import sqlalchemy as sa

revision = 'f1a2b3c4d5e6'
down_revision = 'e7f8a9b0c1d2'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('parkings', sa.Column('category_pricing', sa.Text(), nullable=True))

def downgrade():
    op.drop_column('parkings', 'category_pricing')
