"""add rental reservation fee snapshots

Revision ID: go5p6q7r8s9t
Revises: gn4o5p6q7r8s
"""
from alembic import op
import sqlalchemy as sa

revision = "go5p6q7r8s9t"
down_revision = "gn4o5p6q7r8s"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("rental_reservations", sa.Column("base_amount", sa.Float(), nullable=False, server_default="0"))
    op.add_column("rental_reservations", sa.Column("customer_fee_amount", sa.Float(), nullable=False, server_default="0"))
    op.add_column("rental_reservations", sa.Column("establishment_fee_amount", sa.Float(), nullable=False, server_default="0"))
    op.add_column("rental_reservations", sa.Column("platform_fee_amount", sa.Float(), nullable=False, server_default="0"))
    op.add_column("rental_reservations", sa.Column("final_total", sa.Float(), nullable=False, server_default="0"))
    op.add_column("rental_reservations", sa.Column("platform_fee_snapshot", sa.Text(), nullable=True))


def downgrade():
    op.drop_column("rental_reservations", "platform_fee_snapshot")
    op.drop_column("rental_reservations", "final_total")
    op.drop_column("rental_reservations", "platform_fee_amount")
    op.drop_column("rental_reservations", "establishment_fee_amount")
    op.drop_column("rental_reservations", "customer_fee_amount")
    op.drop_column("rental_reservations", "base_amount")
