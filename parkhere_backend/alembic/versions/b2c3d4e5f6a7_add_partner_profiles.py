"""add partner profiles

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-08-13 00:00:01.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, Sequence[str], None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.create_table(
        "partner_profiles",
        sa.Column("id", sa.CHAR(36), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("tenant_id", sa.String(36), nullable=False),
        sa.Column("service_type", sa.String(40), nullable=False),
        sa.Column("company_name", sa.String(255), nullable=False),
        sa.Column("cnpj", sa.String(20), nullable=False),
        sa.Column("registration_status", sa.String(80), nullable=False),
        sa.Column("responsible_name", sa.String(255), nullable=False),
        sa.Column("has_insurance", sa.Boolean(), nullable=True),
        sa.Column("insurance_provider", sa.String(255), nullable=True),
        sa.Column("instagram", sa.String(255), nullable=True),
        sa.Column("website", sa.String(255), nullable=True),
        sa.Column("social_links", sa.String(500), nullable=True),
        sa.Column("approval_status", sa.String(40), nullable=False),
        sa.ForeignKeyConstraint(["tenant_id"], ["tenants.id"]),
        sa.PrimaryKeyConstraint("id"),
    )


def downgrade():
    op.drop_table("partner_profiles")
