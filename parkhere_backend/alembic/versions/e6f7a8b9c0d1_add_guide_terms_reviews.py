"""add progressive guide terms, schedule and reviews"""

from alembic import op
import sqlalchemy as sa

revision = 'e6f7a8b9c0d1'
down_revision = 'd5e6f7a8b9c0'
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    def add_if_missing(table, column):
        if column.name not in {item['name'] for item in inspector.get_columns(table)}:
            op.add_column(table, column)
    add_if_missing('guide_parking_links', sa.Column('commission_terms', sa.Text(), nullable=True))
    add_if_missing('parkings', sa.Column('guide_commission_terms', sa.Text(), nullable=True))
    add_if_missing('guide_services', sa.Column('schedule', sa.String(1000), nullable=True))
    if 'guide_reviews' not in inspector.get_table_names():
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
    add_if_missing('reservations', sa.Column('guide_platform_fee_amount', sa.Float(), nullable=False, server_default='0'))
    add_if_missing('reservations', sa.Column('guide_payout_amount', sa.Float(), nullable=False, server_default='0'))


def downgrade() -> None:
    op.drop_column('reservations', 'guide_payout_amount')
    op.drop_column('reservations', 'guide_platform_fee_amount')
    op.drop_table('guide_reviews')
    op.drop_column('guide_services', 'schedule')
    op.drop_column('parkings', 'guide_commission_terms')
    op.drop_column('guide_parking_links', 'commission_terms')
