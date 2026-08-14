"""add reservation price snapshot

Revision ID: d4e5f6a7b8c9
Revises: c3d4e5f6a7b8
Create Date: 2026-08-14 00:00:03.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d4e5f6a7b8c9"
down_revision: Union[str, Sequence[str], None] = "c3d4e5f6a7b8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.add_column(
        "reservations",
        sa.Column("spot_type", sa.String(20), nullable=False, server_default="uncovered"),
    )
    op.add_column(
        "reservations",
        sa.Column("pricing_plan", sa.String(20), nullable=False, server_default="hourly"),
    )
    op.add_column(
        "reservations",
        sa.Column("duration_hours", sa.Integer(), nullable=False, server_default="1"),
    )
    op.add_column(
        "reservations",
        sa.Column("base_amount", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "reservations",
        sa.Column("services_amount", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "reservations",
        sa.Column("platform_fee_amount", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "reservations",
        sa.Column("final_total", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "reservations",
        sa.Column("selected_services_snapshot", sa.Text(), nullable=True),
    )
    op.execute(
        """
        UPDATE reservations
        SET
            base_amount = estimated_total,
            final_total = estimated_total
        """
    )


def downgrade():
    op.drop_column("reservations", "selected_services_snapshot")
    op.drop_column("reservations", "final_total")
    op.drop_column("reservations", "platform_fee_amount")
    op.drop_column("reservations", "services_amount")
    op.drop_column("reservations", "base_amount")
    op.drop_column("reservations", "duration_hours")
    op.drop_column("reservations", "pricing_plan")
    op.drop_column("reservations", "spot_type")
