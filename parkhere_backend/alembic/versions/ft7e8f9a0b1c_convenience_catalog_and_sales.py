"""Add reusable convenience categories, barcodes and point-of-sale records."""
from alembic import op
import sqlalchemy as sa

revision = "ft7e8f9a0b1c"
down_revision = "fs6d7e8f9a0b"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "parking_convenience_categories",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("name", sa.String(80), nullable=False),
        sa.Column("subcategory", sa.String(80), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.UniqueConstraint("tenant_id", "name", "subcategory", name="uq_convenience_category_tenant_name_subcategory"),
    )
    op.add_column("parking_convenience_products", sa.Column("category_id", sa.String(36), nullable=True))
    op.add_column("parking_convenience_products", sa.Column("barcode", sa.String(80), nullable=True))
    op.create_foreign_key(
        "fk_convenience_product_category",
        "parking_convenience_products",
        "parking_convenience_categories",
        ["category_id"],
        ["id"],
    )
    op.create_index("ix_convenience_product_barcode", "parking_convenience_products", ["barcode"])
    for table, columns in (
        ("parking_convenience_sales", [
            sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id"), nullable=False),
            sa.Column("parking_id", sa.String(36), sa.ForeignKey("parkings.id"), nullable=False),
            sa.Column("operator_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
            sa.Column("payment_method", sa.String(20), nullable=False, server_default="cash"),
            sa.Column("total_amount", sa.Float(), nullable=False, server_default="0"),
            sa.Column("cash_received", sa.Float(), nullable=True),
            sa.Column("change_amount", sa.Float(), nullable=False, server_default="0"),
        ]),
    ):
        op.create_table(
            table,
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
            *columns,
        )
    op.create_index("ix_convenience_sale_tenant", "parking_convenience_sales", ["tenant_id"])
    op.create_index("ix_convenience_sale_parking", "parking_convenience_sales", ["parking_id"])
    op.create_table(
        "parking_convenience_sale_items",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("sale_id", sa.String(36), sa.ForeignKey("parking_convenience_sales.id"), nullable=False),
        sa.Column("product_id", sa.String(36), sa.ForeignKey("parking_convenience_products.id"), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("unit_price", sa.Float(), nullable=False, server_default="0"),
        sa.Column("total_price", sa.Float(), nullable=False, server_default="0"),
    )
    op.create_index("ix_convenience_sale_item_sale", "parking_convenience_sale_items", ["sale_id"])


def downgrade() -> None:
    op.drop_index("ix_convenience_sale_item_sale", table_name="parking_convenience_sale_items")
    op.drop_table("parking_convenience_sale_items")
    op.drop_index("ix_convenience_sale_parking", table_name="parking_convenience_sales")
    op.drop_index("ix_convenience_sale_tenant", table_name="parking_convenience_sales")
    op.drop_table("parking_convenience_sales")
    op.drop_index("ix_convenience_product_barcode", table_name="parking_convenience_products")
    op.drop_constraint("fk_convenience_product_category", "parking_convenience_products", type_="foreignkey")
    op.drop_column("parking_convenience_products", "barcode")
    op.drop_column("parking_convenience_products", "category_id")
    op.drop_table("parking_convenience_categories")
