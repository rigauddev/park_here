"""associate rental units with parking matrix and add vehicle types

Revision ID: gh8i9j0k1l2m
Revises: gg7h8i9j0k1l
"""
from alembic import op
import sqlalchemy as sa

revision = "gh8i9j0k1l2m"
down_revision = "gg7h8i9j0k1l"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("rental_companies", sa.Column("parent_parking_id", sa.String(36), nullable=True))
    op.add_column("rental_companies", sa.Column("service_type", sa.String(40), nullable=False, server_default="vehicle_rental"))
    op.add_column("rental_companies", sa.Column("unit_kind", sa.String(20), nullable=False, server_default="branch"))
    op.create_foreign_key("fk_rental_company_parent_parking", "rental_companies", "parkings", ["parent_parking_id"], ["id"])
    op.create_index("ix_rental_companies_parent_parking_id", "rental_companies", ["parent_parking_id"])
    op.add_column("rental_vehicles", sa.Column("vehicle_type", sa.String(30), nullable=False, server_default="car"))


def downgrade():
    op.drop_column("rental_vehicles", "vehicle_type")
    op.drop_index("ix_rental_companies_parent_parking_id", table_name="rental_companies")
    op.drop_constraint("fk_rental_company_parent_parking", "rental_companies", type_="foreignkey")
    op.drop_column("rental_companies", "unit_kind")
    op.drop_column("rental_companies", "service_type")
    op.drop_column("rental_companies", "parent_parking_id")
