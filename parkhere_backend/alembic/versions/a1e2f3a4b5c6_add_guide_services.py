"""add guide services"""

from alembic import op
import sqlalchemy as sa

revision = 'a1e2f3a4b5c6'
down_revision = '9d0e1f2a3b4c'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'guide_services',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.Column('guide_user_id', sa.String(36), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('name', sa.String(160), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('price', sa.Float(), nullable=False, server_default='0'),
        sa.Column('duration_minutes', sa.String(20), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
    )


def downgrade() -> None:
    op.drop_table('guide_services')
