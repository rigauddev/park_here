"""add motorhome spot count"""
from alembic import op
import sqlalchemy as sa

revision = 'e7f8a9b0c1d2'
down_revision = 'e6f7a8b9c0d1'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('parkings', sa.Column('moto_home_spots', sa.Integer(), nullable=False, server_default='0'))

def downgrade():
    op.drop_column('parkings', 'moto_home_spots')
