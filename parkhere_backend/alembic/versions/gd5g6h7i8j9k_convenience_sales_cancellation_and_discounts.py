"""Add cancellation, discount, and CPF fields to convenience sales and items.

Revision ID: gd5g6h7i8j9k
Revises: gc4f5g6h7i8j
Create Date: 2026-10-30 14:40:00.000000
"""
from alembic import op
import sqlalchemy as sa

revision = "gd5g6h7i8j9k"
down_revision = "gc4f5g6h7i8j"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Columns for parking_convenience_sales
    op.add_column(
        "parking_convenience_sales",
        sa.Column("status", sa.String(20), nullable=False, server_default="completed"),
    )
    op.add_column(
        "parking_convenience_sales",
        sa.Column("customer_cpf", sa.String(14), nullable=True),
    )
    op.add_column(
        "parking_convenience_sales",
        sa.Column("discount_total", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parking_convenience_sales",
        sa.Column("cancelled_at", sa.DateTime(), nullable=True),
    )
    op.add_column(
        "parking_convenience_sales",
        sa.Column("cancelled_by_id", sa.String(36), sa.ForeignKey("users.id"), nullable=True),
    )
    op.add_column(
        "parking_convenience_sales",
        sa.Column("cancel_reason", sa.String(200), nullable=True),
    )

    # Columns for parking_convenience_sale_items
    op.add_column(
        "parking_convenience_sale_items",
        sa.Column("discount_percent", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "parking_convenience_sale_items",
        sa.Column("discount_amount", sa.Float(), nullable=False, server_default="0"),
    )


def downgrade() -> None:
    op.drop_column("parking_convenience_sale_items", "discount_amount")
    op.drop_column("parking_convenience_sale_items", "discount_percent")
    op.drop_column("parking_convenience_sales", "cancel_reason")
    op.drop_column("parking_convenience_sales", "cancelled_by_id")
    op.drop_column("parking_convenience_sales", "cancelled_at")
    op.drop_column("parking_convenience_sales", "discount_total")
    op.drop_column("parking_convenience_sales", "customer_cpf")
    op.drop_column("parking_convenience_sales", "status")
