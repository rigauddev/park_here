"""Add update and soft-delete timestamps to base model tables.

Revision ID: fn1b2c3d4e5f
Revises: fm1b2c3d4e5f
"""
from alembic import op
import sqlalchemy as sa


revision = "fn1b2c3d4e5f"
down_revision = "fm1b2c3d4e5f"
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    for table_name in inspector.get_table_names():
        if table_name == "alembic_version":
            continue
        existing = {column["name"] for column in inspector.get_columns(table_name)}
        if "updated_at" not in existing:
            op.add_column(
                table_name,
                sa.Column(
                    "updated_at",
                    sa.DateTime(timezone=True),
                    server_default=sa.func.now(),
                    nullable=False,
                ),
            )
        if "deleted_at" not in existing:
            op.add_column(
                table_name,
                sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
            )


def downgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    for table_name in inspector.get_table_names():
        if table_name == "alembic_version":
            continue
        existing = {column["name"] for column in inspector.get_columns(table_name)}
        if "deleted_at" in existing:
            op.drop_column(table_name, "deleted_at")
        if "updated_at" in existing:
            op.drop_column(table_name, "updated_at")
