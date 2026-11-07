"""add ServiceHub vehicle rental module

Revision ID: gg7h8i9j0k1l
Revises: ge6h7i8j9k0l
"""
from alembic import op
import sqlalchemy as sa

revision = "gg7h8i9j0k1l"
down_revision = "ge6h7i8j9k0l"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("rental_companies",
        sa.Column("id", sa.CHAR(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("name", sa.String(120), nullable=False), sa.Column("address", sa.String(200)),
        sa.Column("latitude", sa.Float), sa.Column("longitude", sa.Float), sa.Column("cnpj", sa.String(20)),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.true()),
    )
    op.create_index("ix_rental_companies_tenant_id", "rental_companies", ["tenant_id"])
    op.create_table("rental_vehicles",
        sa.Column("id", sa.CHAR(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("company_id", sa.String(36), sa.ForeignKey("rental_companies.id"), nullable=False),
        sa.Column("model", sa.String(120), nullable=False), sa.Column("brand", sa.String(80), nullable=False),
        sa.Column("price_per_day", sa.Float, nullable=False), sa.Column("status", sa.String(20), nullable=False, server_default="available"),
        sa.Column("plate", sa.String(20)), sa.Column("year", sa.Integer),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.true()),
    )
    op.create_index("ix_rental_vehicles_company_id", "rental_vehicles", ["company_id"])
    op.create_table("rental_reservations",
        sa.Column("id", sa.CHAR(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("company_id", sa.String(36), sa.ForeignKey("rental_companies.id"), nullable=False),
        sa.Column("vehicle_id", sa.String(36), sa.ForeignKey("rental_vehicles.id"), nullable=False),
        sa.Column("start_date", sa.DateTime(timezone=True), nullable=False), sa.Column("end_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("total_price", sa.Float, nullable=False), sa.Column("status", sa.String(24), nullable=False, server_default="pending"),
        sa.Column("extras", sa.Text), sa.Column("km_start", sa.Integer), sa.Column("km_end", sa.Integer),
    )
    for column in ("tenant_id", "user_id", "company_id", "vehicle_id"):
        op.create_index(f"ix_rental_reservations_{column}", "rental_reservations", [column])
    for table in ("rental_checkins", "rental_checkouts"):
        op.create_table(table,
            sa.Column("id", sa.CHAR(36), primary_key=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("reservation_id", sa.String(36), sa.ForeignKey("rental_reservations.id"), nullable=False, unique=True),
            sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False), sa.Column("km", sa.Integer),
            sa.Column("photos", sa.JSON), sa.Column("items", sa.JSON), sa.Column("notes", sa.String(1000)),
            *( [sa.Column("damage_fine", sa.Float, nullable=False, server_default="0")] if table.endswith("checkouts") else [] ),
        )
        op.create_index(f"ix_{table}_reservation_id", table, ["reservation_id"])


def downgrade():
    op.drop_table("rental_checkouts"); op.drop_table("rental_checkins"); op.drop_table("rental_reservations"); op.drop_table("rental_vehicles"); op.drop_table("rental_companies")
