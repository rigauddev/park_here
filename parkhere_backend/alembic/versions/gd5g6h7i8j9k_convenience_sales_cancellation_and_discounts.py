"""Add cancellation, discount, and CPF fields to convenience sales and items.

Revision ID: gd5g6h7i8j9k
Revises: gc4f5g6h7i8j
Create Date: 2026-10-30 14:40:00.000000
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.engine.reflection import Inspector

revision = "gd5g6h7i8j9k"
down_revision = "gc4f5g6h7i8j"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = Inspector.from_engine(conn)

    existing_sales_cols = {col["name"] for col in inspector.get_columns("parking_convenience_sales")}
    existing_items_cols = {col["name"] for col in inspector.get_columns("parking_convenience_sale_items")}

    # Columns for parking_convenience_sales
    if "status" not in existing_sales_cols:
        op.add_column(
            "parking_convenience_sales",
            sa.Column("status", sa.String(20), nullable=False, server_default="completed"),
        )
    if "customer_cpf" not in existing_sales_cols:
        op.add_column(
            "parking_convenience_sales",
            sa.Column("customer_cpf", sa.String(14), nullable=True),
        )
    if "discount_total" not in existing_sales_cols:
        op.add_column(
            "parking_convenience_sales",
            sa.Column("discount_total", sa.Float(), nullable=False, server_default="0"),
        )
    if "cancelled_at" not in existing_sales_cols:
        op.add_column(
            "parking_convenience_sales",
            sa.Column("cancelled_at", sa.DateTime(), nullable=True),
        )
    if "cancelled_by_id" not in existing_sales_cols:
        op.add_column(
            "parking_convenience_sales",
            sa.Column("cancelled_by_id", sa.String(36), nullable=True),
        )
    if "cancel_reason" not in existing_sales_cols:
        op.add_column(
            "parking_convenience_sales",
            sa.Column("cancel_reason", sa.String(200), nullable=True),
        )

    # Columns for parking_convenience_sale_items
    if "discount_percent" not in existing_items_cols:
        op.add_column(
            "parking_convenience_sale_items",
            sa.Column("discount_percent", sa.Float(), nullable=False, server_default="0"),
        )
    if "discount_amount" not in existing_items_cols:
        op.add_column(
            "parking_convenience_sale_items",
            sa.Column("discount_amount", sa.Float(), nullable=False, server_default="0"),
        )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = Inspector.from_engine(conn)

    existing_sales_cols = {col["name"] for col in inspector.get_columns("parking_convenience_sales")}
    existing_items_cols = {col["name"] for col in inspector.get_columns("parking_convenience_sale_items")}

    if "discount_amount" in existing_items_cols:
        op.drop_column("parking_convenience_sale_items", "discount_amount")
    if "discount_percent" in existing_items_cols:
        op.drop_column("parking_convenience_sale_items", "discount_percent")
    if "cancel_reason" in existing_sales_cols:
        op.drop_column("parking_convenience_sales", "cancel_reason")
    if "cancelled_by_id" in existing_sales_cols:
        op.drop_column("parking_convenience_sales", "cancelled_by_id")
    if "cancelled_at" in existing_sales_cols:
        op.drop_column("parking_convenience_sales", "cancelled_at")
    if "discount_total" in existing_sales_cols:
        op.drop_column("parking_convenience_sales", "discount_total")
    if "customer_cpf" in existing_sales_cols:
        op.drop_column("parking_convenience_sales", "customer_cpf")
    if "status" in existing_sales_cols:
        op.drop_column("parking_convenience_sales", "status")
