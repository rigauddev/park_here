"""store rental company city for service discovery

Revision ID: gt9u1v2w3x4y
Revises: gs8t0u1v2w3x
"""
from alembic import op
import sqlalchemy as sa

revision = "gt9u1v2w3x4y"
down_revision = "gs8t0u1v2w3x"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("rental_companies", sa.Column("city", sa.String(120), nullable=True))
    op.create_index("ix_rental_companies_city", "rental_companies", ["city"])


def downgrade():
    op.drop_index("ix_rental_companies_city", table_name="rental_companies")
    op.drop_column("rental_companies", "city")
