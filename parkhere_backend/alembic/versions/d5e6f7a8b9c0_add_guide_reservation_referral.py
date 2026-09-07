"""add guide referral to reservations"""

from alembic import op
import sqlalchemy as sa

revision = 'd5e6f7a8b9c0'
down_revision = 'c4d5e6f7a8b9'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # The original guide tables predate the shared BaseModel defaults. Add
    # database-side timestamps so API-created affiliations/services work on
    # MySQL as well as SQLite.
    op.alter_column(
        'guide_parking_links',
        'created_at',
        existing_type=sa.DateTime(),
        server_default=sa.func.now(),
    )
    op.alter_column(
        'guide_parking_links',
        'updated_at',
        existing_type=sa.DateTime(),
        server_default=sa.func.now(),
    )
    op.alter_column(
        'guide_services',
        'created_at',
        existing_type=sa.DateTime(),
        server_default=sa.func.now(),
    )
    op.alter_column(
        'guide_services',
        'updated_at',
        existing_type=sa.DateTime(),
        server_default=sa.func.now(),
    )
    op.add_column('reservations', sa.Column('guide_user_id', sa.String(36), sa.ForeignKey('users.id'), nullable=True))
    op.add_column('reservations', sa.Column('guide_commission_amount', sa.Float(), nullable=False, server_default='0'))


def downgrade() -> None:
    op.drop_column('reservations', 'guide_commission_amount')
    op.drop_column('reservations', 'guide_user_id')
