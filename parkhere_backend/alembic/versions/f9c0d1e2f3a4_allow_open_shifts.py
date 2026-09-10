"""allow open shifts without an operator

Revision ID: f9c0d1e2f3a4
Revises: f8b9c0d1e2f3
"""
from alembic import op
import sqlalchemy as sa

revision = "f9c0d1e2f3a4"
down_revision = "f8b9c0d1e2f3"
branch_labels = None
depends_on = None

def upgrade():
    op.alter_column("operator_work_shifts", "operator_id", existing_type=sa.String(36), nullable=True)

def downgrade():
    op.alter_column("operator_work_shifts", "operator_id", existing_type=sa.String(36), nullable=False)
