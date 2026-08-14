"""add parking management fields

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-08-13 00:00:02.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c3d4e5f6a7b8"
down_revision: Union[str, Sequence[str], None] = "b2c3d4e5f6a7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.add_column(
        "parkings",
        sa.Column("covered_spots", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parkings",
        sa.Column("uncovered_spots", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parkings",
        sa.Column("weekly_price", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parkings",
        sa.Column("covered_first_hour_price", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parkings",
        sa.Column("covered_additional_hour_price", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parkings",
        sa.Column("covered_daily_price", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parkings",
        sa.Column("covered_weekly_price", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parkings",
        sa.Column("covered_monthly_price", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parkings",
        sa.Column("uncovered_first_hour_price", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parkings",
        sa.Column("uncovered_additional_hour_price", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parkings",
        sa.Column("uncovered_daily_price", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parkings",
        sa.Column("uncovered_weekly_price", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parkings",
        sa.Column("uncovered_monthly_price", sa.Float(), nullable=False, server_default="0"),
    )

    op.execute(
        """
        UPDATE parkings
        SET
            uncovered_spots = total_spots,
            weekly_price = COALESCE(daily_price, 0) * 5,
            uncovered_first_hour_price = COALESCE(first_hour_price, 0),
            uncovered_additional_hour_price = COALESCE(additional_hour_price, 0),
            uncovered_daily_price = COALESCE(daily_price, 0),
            uncovered_weekly_price = COALESCE(daily_price, 0) * 5,
            uncovered_monthly_price = COALESCE(monthly_price, 0),
            covered_first_hour_price = COALESCE(first_hour_price, 0),
            covered_additional_hour_price = COALESCE(additional_hour_price, 0),
            covered_daily_price = COALESCE(daily_price, 0),
            covered_weekly_price = COALESCE(daily_price, 0) * 5,
            covered_monthly_price = COALESCE(monthly_price, 0)
        """
    )


def downgrade():
    op.drop_column("parkings", "uncovered_monthly_price")
    op.drop_column("parkings", "uncovered_weekly_price")
    op.drop_column("parkings", "uncovered_daily_price")
    op.drop_column("parkings", "uncovered_additional_hour_price")
    op.drop_column("parkings", "uncovered_first_hour_price")
    op.drop_column("parkings", "covered_monthly_price")
    op.drop_column("parkings", "covered_weekly_price")
    op.drop_column("parkings", "covered_daily_price")
    op.drop_column("parkings", "covered_additional_hour_price")
    op.drop_column("parkings", "covered_first_hour_price")
    op.drop_column("parkings", "weekly_price")
    op.drop_column("parkings", "uncovered_spots")
    op.drop_column("parkings", "covered_spots")
