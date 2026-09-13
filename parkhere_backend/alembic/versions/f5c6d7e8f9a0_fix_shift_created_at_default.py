"""add server defaults to operator assignment timestamps"""
from alembic import op
import sqlalchemy as sa

revision = "f5c6d7e8f9a0"
down_revision = "f4b5c6d7e8f9"
branch_labels = None
depends_on = None


def upgrade():
    for table in ("operator_parking_assignments", "operator_work_shifts"):
        op.alter_column(
            table,
            "created_at",
            existing_type=sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            existing_nullable=False,
        )


def downgrade():
    for table in ("operator_parking_assignments", "operator_work_shifts"):
        op.alter_column(
            table,
            "created_at",
            existing_type=sa.DateTime(),
            server_default=None,
            existing_nullable=False,
        )
