"""add parking operational fields

Revision ID: a7b8c9d0e1f2
Revises: f6a7b8c9d0e1
Create Date: 2026-08-14 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "a7b8c9d0e1f2"
down_revision = "f6a7b8c9d0e1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "parkings",
        sa.Column("has_24h_gate", sa.Boolean(), nullable=True, server_default=sa.text("0")),
    )
    op.add_column(
        "parkings",
        sa.Column(
            "has_security_system",
            sa.Boolean(),
            nullable=True,
            server_default=sa.text("0"),
        ),
    )
    op.add_column(
        "parkings",
        sa.Column(
            "wants_automatic_access",
            sa.Boolean(),
            nullable=True,
            server_default=sa.text("0"),
        ),
    )
    op.add_column(
        "parkings",
        sa.Column(
            "has_automatic_access",
            sa.Boolean(),
            nullable=True,
            server_default=sa.text("0"),
        ),
    )


def downgrade() -> None:
    op.drop_column("parkings", "has_automatic_access")
    op.drop_column("parkings", "wants_automatic_access")
    op.drop_column("parkings", "has_security_system")
    op.drop_column("parkings", "has_24h_gate")
