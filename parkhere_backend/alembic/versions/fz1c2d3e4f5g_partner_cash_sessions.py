"""add operator cash sessions

Revision ID: fz1c2d3e4f5g
Revises: fy1b2c3d4e5f
"""
from alembic import op
import sqlalchemy as sa

revision = "fz1c2d3e4f5g"
down_revision = "fy1b2c3d4e5f"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "partner_cash_sessions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("operator_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("parking_id", sa.String(36), sa.ForeignKey("parkings.id"), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="open"),
        sa.Column("opened_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("parking_opening_cash", sa.Float, nullable=False, server_default="0"),
        sa.Column("convenience_opening_cash", sa.Float, nullable=False, server_default="0"),
        sa.Column("parking_closing_cash", sa.Float, nullable=True),
        sa.Column("convenience_closing_cash", sa.Float, nullable=True),
        sa.Column("closing_notes", sa.String(500), nullable=True),
    )


def downgrade():
    op.drop_table("partner_cash_sessions")
