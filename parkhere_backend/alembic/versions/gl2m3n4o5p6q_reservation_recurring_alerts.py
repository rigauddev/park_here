"""add reservation recurring and check-in alert fields

Revision ID: gl2m3n4o5p6q
Revises: gk1l2m3n4o5p
"""
from alembic import op
import sqlalchemy as sa

revision = "gl2m3n4o5p6q"
down_revision = "gk1l2m3n4o5p"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("reservations", sa.Column("is_recurring", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.add_column("reservations", sa.Column("recurring_discount_percent", sa.Float(), nullable=False, server_default="0"))
    op.add_column("reservations", sa.Column("needs_checkin_alert", sa.Boolean(), nullable=False, server_default=sa.false()))


def downgrade():
    op.drop_column("reservations", "needs_checkin_alert")
    op.drop_column("reservations", "recurring_discount_percent")
    op.drop_column("reservations", "is_recurring")
