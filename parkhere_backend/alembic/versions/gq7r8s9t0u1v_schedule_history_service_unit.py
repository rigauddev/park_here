"""support schedule history for non-parking service units

Revision ID: gq7r8s9t0u1v
Revises: gp6q7r8s9t0u
"""
from alembic import op
import sqlalchemy as sa

revision = "gq7r8s9t0u1v"
down_revision = "gp6q7r8s9t0u"
branch_labels = None
depends_on = None


def upgrade():
    op.alter_column("operator_schedule_history", "parking_id", existing_type=sa.String(36), nullable=True)
    op.add_column("operator_schedule_history", sa.Column("rental_company_id", sa.String(36), nullable=True))
    op.create_foreign_key(
        "fk_schedule_history_rental_company",
        "operator_schedule_history",
        "rental_companies",
        ["rental_company_id"],
        ["id"],
    )
    op.add_column("operator_schedule_history", sa.Column("service_type", sa.String(40), nullable=False, server_default="parking"))


def downgrade():
    op.drop_column("operator_schedule_history", "service_type")
    op.drop_constraint("fk_schedule_history_rental_company", "operator_schedule_history", type_="foreignkey")
    op.drop_column("operator_schedule_history", "rental_company_id")
    op.alter_column("operator_schedule_history", "parking_id", existing_type=sa.String(36), nullable=False)
