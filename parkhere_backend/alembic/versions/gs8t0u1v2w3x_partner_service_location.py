"""store partner service location for city discovery

Revision ID: gs8t0u1v2w3x
Revises: gr8s9t0u1v2w
"""
from alembic import op
import sqlalchemy as sa

revision = "gs8t0u1v2w3x"
down_revision = "gr8s9t0u1v2w"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("partner_profiles", sa.Column("city", sa.String(120), nullable=True))
    op.add_column("partner_profiles", sa.Column("latitude", sa.Float(), nullable=True))
    op.add_column("partner_profiles", sa.Column("longitude", sa.Float(), nullable=True))
    op.create_index("ix_partner_profiles_city", "partner_profiles", ["city"])


def downgrade():
    op.drop_index("ix_partner_profiles_city", table_name="partner_profiles")
    op.drop_column("partner_profiles", "longitude")
    op.drop_column("partner_profiles", "latitude")
    op.drop_column("partner_profiles", "city")
