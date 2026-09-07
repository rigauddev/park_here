"""add commission terms to guide parking links"""

from alembic import op
import sqlalchemy as sa

revision = '9d0e1f2a3b4c'
down_revision = '8c9d0e1f2a3b'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('guide_parking_links', sa.Column('commission_type', sa.String(20), nullable=True))
    op.add_column('guide_parking_links', sa.Column('commission_value', sa.String(30), nullable=True))


def downgrade() -> None:
    op.drop_column('guide_parking_links', 'commission_value')
    op.drop_column('guide_parking_links', 'commission_type')
