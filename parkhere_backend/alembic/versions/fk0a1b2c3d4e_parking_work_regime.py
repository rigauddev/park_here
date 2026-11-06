"""Persist the unit's work-schedule regime separately from opening hours.

Revision ID: fk0a1b2c3d4e
Revises: fj8d9e0a1b2c
"""
from alembic import op
import sqlalchemy as sa

revision = "fk0a1b2c3d4e"
down_revision = "fj8d9e0a1b2c"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "parkings",
        sa.Column(
            "work_regime",
            sa.String(length=30),
            nullable=False,
            server_default="commercial",
        ),
    )


def downgrade():
    op.drop_column("parkings", "work_regime")
