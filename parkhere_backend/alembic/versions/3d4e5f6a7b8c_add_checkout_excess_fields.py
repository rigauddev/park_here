"""add checkout excess fields

Revision ID: 3d4e5f6a7b8c
Revises: 2c3d4e5f6a7b
Create Date: 2026-08-17 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "3d4e5f6a7b8c"
down_revision = "2c3d4e5f6a7b"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "reservations",
        sa.Column(
            "checkout_grace_minutes",
            sa.Integer(),
            nullable=False,
            server_default="15",
        ),
    )
    op.add_column(
        "reservations",
        sa.Column(
            "checkout_excess_minutes",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "reservations",
        sa.Column(
            "checkout_excess_amount",
            sa.Float(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "reservations",
        sa.Column("checkout_excess_paid_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "payment_transactions",
        sa.Column(
            "payment_purpose",
            sa.String(length=40),
            nullable=False,
            server_default="reservation",
        ),
    )


def downgrade():
    op.drop_column("payment_transactions", "payment_purpose")
    op.drop_column("reservations", "checkout_excess_paid_at")
    op.drop_column("reservations", "checkout_excess_amount")
    op.drop_column("reservations", "checkout_excess_minutes")
    op.drop_column("reservations", "checkout_grace_minutes")
