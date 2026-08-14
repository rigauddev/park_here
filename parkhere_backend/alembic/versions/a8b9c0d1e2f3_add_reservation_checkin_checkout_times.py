"""add reservation checkin checkout times

Revision ID: a8b9c0d1e2f3
Revises: f7a8b9c0d1e2
Create Date: 2026-08-14 00:00:02.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a8b9c0d1e2f3"
down_revision: Union[str, Sequence[str], None] = "f7a8b9c0d1e2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.add_column("reservations", sa.Column("checked_in_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("reservations", sa.Column("checked_out_at", sa.DateTime(timezone=True), nullable=True))


def downgrade():
    op.drop_column("reservations", "checked_out_at")
    op.drop_column("reservations", "checked_in_at")
