"""persist reservation payment method
Revision ID: fd3a4b5c6d7e
Revises: fc2f3a4b5c6d
"""
from alembic import op
import sqlalchemy as sa
revision = "fd3a4b5c6d7e"
down_revision = "fc2f3a4b5c6d"
branch_labels = None
depends_on = None
def upgrade():
    op.add_column("reservations", sa.Column("payment_method", sa.String(20), nullable=True))
def downgrade():
    op.drop_column("reservations", "payment_method")
