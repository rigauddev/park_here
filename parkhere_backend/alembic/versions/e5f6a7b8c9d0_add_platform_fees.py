"""add platform fees

Revision ID: e5f6a7b8c9d0
Revises: d4e5f6a7b8c9
Create Date: 2026-08-14 00:00:04.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e5f6a7b8c9d0"
down_revision: Union[str, Sequence[str], None] = "d4e5f6a7b8c9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.create_table(
        "platform_fees",
        sa.Column("id", sa.CHAR(36), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("service_type", sa.String(50), nullable=False),
        sa.Column("fee_mode", sa.String(20), nullable=False),
        sa.Column("fixed_amount", sa.Float(), nullable=False),
        sa.Column("percentage", sa.Float(), nullable=False),
        sa.Column("min_fee", sa.Float(), nullable=False),
        sa.Column("max_fee", sa.Float(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("service_type"),
    )
    op.add_column(
        "reservations",
        sa.Column("platform_fee_snapshot", sa.Text(), nullable=True),
    )


def downgrade():
    op.drop_column("reservations", "platform_fee_snapshot")
    op.drop_table("platform_fees")
