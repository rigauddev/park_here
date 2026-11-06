"""add rental plans and fleet maintenance

Revision ID: gj0k1l2m3n4o
Revises: gi9j0k1l2m3n
"""
from alembic import op
import sqlalchemy as sa

revision = "gj0k1l2m3n4o"
down_revision = "gi9j0k1l2m3n"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "rental_plans",
        sa.Column("id", sa.CHAR(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("company_id", sa.String(36), sa.ForeignKey("rental_companies.id"), nullable=False),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("description", sa.Text),
        sa.Column("vehicle_type", sa.String(30)),
        sa.Column("price_per_day", sa.Float, nullable=False),
        sa.Column("price_per_week", sa.Float),
        sa.Column("price_per_month", sa.Float),
        sa.Column("deposit_amount", sa.Float, nullable=False, server_default="0"),
        sa.Column("included_items", sa.JSON),
        sa.Column("mileage_limit_per_day", sa.Integer),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.true()),
    )
    op.create_index("ix_rental_plans_company_id", "rental_plans", ["company_id"])
    op.add_column("rental_reservations", sa.Column("plan_id", sa.String(36), nullable=True))
    op.create_foreign_key("fk_rental_reservation_plan", "rental_reservations", "rental_plans", ["plan_id"], ["id"])
    op.create_index("ix_rental_reservations_plan_id", "rental_reservations", ["plan_id"])
    op.create_table(
        "rental_maintenances",
        sa.Column("id", sa.CHAR(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("vehicle_id", sa.String(36), sa.ForeignKey("rental_vehicles.id"), nullable=False),
        sa.Column("maintenance_type", sa.String(40), nullable=False),
        sa.Column("description", sa.Text),
        sa.Column("performed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("next_due_at", sa.DateTime(timezone=True)),
        sa.Column("odometer", sa.Integer),
        sa.Column("cost", sa.Float),
        sa.Column("status", sa.String(20), nullable=False, server_default="completed"),
    )
    op.create_index("ix_rental_maintenances_vehicle_id", "rental_maintenances", ["vehicle_id"])


def downgrade():
    op.drop_index("ix_rental_maintenances_vehicle_id", table_name="rental_maintenances")
    op.drop_table("rental_maintenances")
    op.drop_index("ix_rental_reservations_plan_id", table_name="rental_reservations")
    op.drop_constraint("fk_rental_reservation_plan", "rental_reservations", type_="foreignkey")
    op.drop_column("rental_reservations", "plan_id")
    op.drop_index("ix_rental_plans_company_id", table_name="rental_plans")
    op.drop_table("rental_plans")
