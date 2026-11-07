"""add rental fleet payment status and category blocking

Revision ID: gr8s9t0u1v2w
Revises: gq7r8s9t0u1v
"""
from alembic import op
import sqlalchemy as sa

revision = "gr8s9t0u1v2w"
down_revision = "gq7r8s9t0u1v"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("rental_reservations", sa.Column("payment_status", sa.String(32), nullable=False, server_default="pending"))
    op.add_column("rental_vehicle_groups", sa.Column("is_blocked", sa.Boolean(), nullable=False, server_default=sa.false()))


def downgrade():
    op.drop_column("rental_vehicle_groups", "is_blocked")
    op.drop_column("rental_reservations", "payment_status")
