"""add operator work profiles and schedule history

Revision ID: f8b9c0d1e2f3
Revises: f5c6d7e8f9a0
"""
from alembic import op
import sqlalchemy as sa

revision = "f8b9c0d1e2f3"
down_revision = "f5c6d7e8f9a0"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "operator_work_profiles",
        sa.Column("id", sa.CHAR(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("operator_id", sa.String(36), nullable=False),
        sa.Column("parking_id", sa.String(36), nullable=False),
        sa.Column("daily_hours", sa.Float(), nullable=False, server_default="8"),
        sa.Column("lunch_minutes", sa.Integer(), nullable=False, server_default="60"),
        sa.Column("days_off", sa.Text(), nullable=False),
        sa.ForeignKeyConstraint(["operator_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["parking_id"], ["parkings.id"]),
        sa.UniqueConstraint("operator_id", "parking_id"),
    )
    op.create_table(
        "operator_schedule_history",
        sa.Column("id", sa.CHAR(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("parking_id", sa.String(36), nullable=False),
        sa.Column("changed_by", sa.String(36), nullable=False),
        sa.Column("action", sa.String(40), nullable=False),
        sa.Column("details", sa.Text(), nullable=False),
        sa.ForeignKeyConstraint(["parking_id"], ["parkings.id"]),
        sa.ForeignKeyConstraint(["changed_by"], ["users.id"]),
    )


def downgrade():
    op.drop_table("operator_schedule_history")
    op.drop_table("operator_work_profiles")
