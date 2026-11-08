"""allow operator shifts for rental service units

Revision ID: gp6q7r8s9t0u
Revises: go5p6q7r8s9t
"""
from alembic import op
import sqlalchemy as sa

revision = "gp6q7r8s9t0u"
down_revision = "go5p6q7r8s9t"
branch_labels = None
depends_on = None


def upgrade():
    op.alter_column("operator_work_shifts", "parking_id", existing_type=sa.String(36), nullable=True)
    op.add_column("operator_work_shifts", sa.Column("rental_company_id", sa.String(36), nullable=True))
    op.create_foreign_key(
        "fk_operator_shift_rental_company",
        "operator_work_shifts",
        "rental_companies",
        ["rental_company_id"],
        ["id"],
    )
    op.create_index("ix_operator_work_shifts_rental_company_id", "operator_work_shifts", ["rental_company_id"])
    op.add_column("operator_work_shifts", sa.Column("service_type", sa.String(40), nullable=False, server_default="parking"))


def downgrade():
    op.drop_column("operator_work_shifts", "service_type")
    op.drop_index("ix_operator_work_shifts_rental_company_id", table_name="operator_work_shifts")
    op.drop_constraint("fk_operator_shift_rental_company", "operator_work_shifts", type_="foreignkey")
    op.drop_column("operator_work_shifts", "rental_company_id")
    op.alter_column("operator_work_shifts", "parking_id", existing_type=sa.String(36), nullable=False)
