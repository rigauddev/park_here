"""add rental configurable items, contracts and fines

Revision ID: gk1l2m3n4o5p
Revises: gj0k1l2m3n4o
"""
from alembic import op
import sqlalchemy as sa

revision = "gk1l2m3n4o5p"
down_revision = "gj0k1l2m3n4o"
branch_labels = None
depends_on = None


def _base(table, *columns):
    op.create_table(
        table,
        sa.Column("id", sa.CHAR(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        *columns,
    )


def upgrade():
    _base(
        "rental_items",
        sa.Column("company_id", sa.String(36), sa.ForeignKey("rental_companies.id"), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("category", sa.String(40), nullable=False, server_default="accessory"),
        sa.Column("description", sa.Text),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.true()),
    )
    op.create_index("ix_rental_items_company_id", "rental_items", ["company_id"])
    _base(
        "rental_contracts",
        sa.Column("reservation_id", sa.String(36), sa.ForeignKey("rental_reservations.id"), nullable=False, unique=True),
        sa.Column("version", sa.String(30), nullable=False, server_default="mvp-1"),
        sa.Column("terms_text", sa.Text, nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("customer_accepted_at", sa.DateTime(timezone=True)),
        sa.Column("partner_accepted_at", sa.DateTime(timezone=True)),
        sa.Column("pdf_path", sa.String(500)),
    )
    op.create_index("ix_rental_contracts_reservation_id", "rental_contracts", ["reservation_id"])
    _base(
        "rental_fines",
        sa.Column("reservation_id", sa.String(36), sa.ForeignKey("rental_reservations.id"), nullable=False),
        sa.Column("vehicle_id", sa.String(36), sa.ForeignKey("rental_vehicles.id"), nullable=False),
        sa.Column("fine_type", sa.String(40), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("amount", sa.Float, nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("evidence_url", sa.String(500)),
        sa.Column("notes", sa.Text),
    )
    op.create_index("ix_rental_fines_reservation_id", "rental_fines", ["reservation_id"])
    op.create_index("ix_rental_fines_vehicle_id", "rental_fines", ["vehicle_id"])


def downgrade():
    op.drop_index("ix_rental_fines_vehicle_id", table_name="rental_fines")
    op.drop_index("ix_rental_fines_reservation_id", table_name="rental_fines")
    op.drop_table("rental_fines")
    op.drop_index("ix_rental_contracts_reservation_id", table_name="rental_contracts")
    op.drop_table("rental_contracts")
    op.drop_index("ix_rental_items_company_id", table_name="rental_items")
    op.drop_table("rental_items")
