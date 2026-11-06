"""allow rental units to belong to any service unit

Revision ID: gi9j0k1l2m3n
Revises: gh8i9j0k1l2m
"""
from alembic import op
import sqlalchemy as sa

revision = "gi9j0k1l2m3n"
down_revision = "gh8i9j0k1l2m"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("rental_companies", sa.Column("parent_unit_id", sa.String(36), nullable=True))
    op.add_column("rental_companies", sa.Column("parent_service_type", sa.String(40), nullable=True))
    op.create_index("ix_rental_companies_parent_unit_id", "rental_companies", ["parent_unit_id"])


def downgrade():
    op.drop_index("ix_rental_companies_parent_unit_id", table_name="rental_companies")
    op.drop_column("rental_companies", "parent_service_type")
    op.drop_column("rental_companies", "parent_unit_id")
