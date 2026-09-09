"""add parking city

Revision ID: 0a1b2c3d4e5f
Revises: b9c0d1e2f3a4
Create Date: 2026-08-17 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "0a1b2c3d4e5f"
down_revision = "b9c0d1e2f3a4"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "parkings",
        sa.Column(
            "city",
            sa.String(length=120),
            nullable=False,
            server_default="Valenca",
        ),
    )
    op.execute(
        "UPDATE parkings SET city = 'Salvador' "
        "WHERE address LIKE '%Salvador%' OR name LIKE '%Salvador%'"
    )
    op.execute(
        "UPDATE parkings SET city = 'Valenca' "
        "WHERE address LIKE '%Valenca%' OR address LIKE '%Valença%'"
    )


def downgrade():
    op.drop_column("parkings", "city")
