"""Add secure guide to parking links."""
from alembic import op
import sqlalchemy as sa

revision = '6a7b8c9d0e1f'
down_revision = '5f6a7b8c9d0e'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'guide_parking_links',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('guide_user_id', sa.String(36), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('parking_id', sa.String(36), sa.ForeignKey('parkings.id'), nullable=False),
        sa.Column('status', sa.String(20), nullable=False, server_default='pending'),
        sa.UniqueConstraint('guide_user_id', 'parking_id'),
    )


def downgrade() -> None:
    op.drop_table('guide_parking_links')
