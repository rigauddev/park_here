"""Track staff creator independently from customer.

Revision ID: fo2c3d4e5f6a
Revises: fn1b2c3d4e5f
"""
from alembic import op
import sqlalchemy as sa

revision = "fo2c3d4e5f6a"
down_revision = "fn1b2c3d4e5f"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("reservations", sa.Column("created_by_user_id", sa.String(36), nullable=True))
    op.create_foreign_key(
        "fk_reservations_created_by_user_id", "reservations", "users",
        ["created_by_user_id"], ["id"],
    )


def downgrade():
    op.drop_constraint("fk_reservations_created_by_user_id", "reservations", type_="foreignkey")
    op.drop_column("reservations", "created_by_user_id")
