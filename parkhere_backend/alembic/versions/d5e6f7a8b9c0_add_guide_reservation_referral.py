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
    op.add_column('guide_parking_links', sa.Column('commission_terms', sa.Text(), nullable=True))
    op.add_column('parkings', sa.Column('guide_commission_terms', sa.Text(), nullable=True))
    op.create_table(
        'guide_reviews',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('guide_user_id', sa.String(36), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('reservation_id', sa.String(36), sa.ForeignKey('reservations.id'), nullable=False),
        sa.Column('customer_user_id', sa.String(36), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('rating', sa.String(10), nullable=False),
        sa.Column('comment', sa.Text(), nullable=True),
        sa.UniqueConstraint('reservation_id'),
    )
    op.add_column('reservations', sa.Column('guide_user_id', sa.String(36), sa.ForeignKey('users.id'), nullable=True))
    op.add_column('reservations', sa.Column('guide_commission_amount', sa.Float(), nullable=False, server_default='0'))
    op.add_column('reservations', sa.Column('guide_platform_fee_amount', sa.Float(), nullable=False, server_default='0'))
    op.add_column('reservations', sa.Column('guide_payout_amount', sa.Float(), nullable=False, server_default='0'))


def downgrade() -> None:
    op.drop_table('guide_reviews')
    op.drop_column('guide_parking_links', 'commission_terms')
    op.drop_column('parkings', 'guide_commission_terms')
    op.drop_column('reservations', 'guide_payout_amount')
    op.drop_column('reservations', 'guide_platform_fee_amount')
    op.drop_column('reservations', 'guide_commission_amount')
    op.drop_column('reservations', 'guide_user_id')
