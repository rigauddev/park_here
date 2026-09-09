"""add customer and establishment payment fee breakdown"""

from alembic import op
import sqlalchemy as sa

revision = 'c4d5e6f7a8b9'
down_revision = 'a1e2f3a4b5c6'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('payment_transactions', sa.Column('customer_fee_amount', sa.Float(), nullable=False, server_default='0'))
    op.add_column('payment_transactions', sa.Column('establishment_fee_amount', sa.Float(), nullable=False, server_default='0'))


def downgrade() -> None:
    op.drop_column('payment_transactions', 'establishment_fee_amount')
    op.drop_column('payment_transactions', 'customer_fee_amount')
