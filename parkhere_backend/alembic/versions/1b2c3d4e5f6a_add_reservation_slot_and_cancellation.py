"""add reservation slot and cancellation fields

Revision ID: 1b2c3d4e5f6a
Revises: 0a1b2c3d4e5f
Create Date: 2026-08-17 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "1b2c3d4e5f6a"
down_revision = "0a1b2c3d4e5f"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("reservations", sa.Column("spot_code", sa.String(length=20), nullable=True))
    op.add_column(
        "reservations",
        sa.Column("arrival_estimate_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "reservations",
        sa.Column(
            "is_manual_arrival",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column(
        "reservations",
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "reservations",
        sa.Column("cancelled_by_user_id", sa.String(length=36), nullable=True),
    )
    op.add_column("reservations", sa.Column("cancellation_reason", sa.Text(), nullable=True))
    op.add_column(
        "reservations",
        sa.Column(
            "cancellation_fee_amount",
            sa.Float(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "reservations",
        sa.Column(
            "cancellation_credit_amount",
            sa.Float(),
            nullable=False,
            server_default="0",
        ),
    )
    op.create_foreign_key(
        "fk_reservations_cancelled_by_user_id_users",
        "reservations",
        "users",
        ["cancelled_by_user_id"],
        ["id"],
    )
    op.execute(
        "UPDATE reservations SET arrival_estimate_at = "
        "DATE_ADD(created_at, INTERVAL route_minutes MINUTE) "
        "WHERE arrival_estimate_at IS NULL"
    )


def downgrade():
    op.drop_constraint(
        "fk_reservations_cancelled_by_user_id_users",
        "reservations",
        type_="foreignkey",
    )
    op.drop_column("reservations", "cancellation_credit_amount")
    op.drop_column("reservations", "cancellation_fee_amount")
    op.drop_column("reservations", "cancellation_reason")
    op.drop_column("reservations", "cancelled_by_user_id")
    op.drop_column("reservations", "cancelled_at")
    op.drop_column("reservations", "is_manual_arrival")
    op.drop_column("reservations", "arrival_estimate_at")
    op.drop_column("reservations", "spot_code")
