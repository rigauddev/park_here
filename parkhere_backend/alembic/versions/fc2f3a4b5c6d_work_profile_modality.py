"""work profile modality and bank hours
Revision ID: fc2f3a4b5c6d
Revises: fb1e2f3a4b5c
"""
from alembic import op
import sqlalchemy as sa
revision = "fc2f3a4b5c6d"
down_revision = "fb1e2f3a4b5c"
branch_labels = None
depends_on = None
def upgrade():
    op.add_column("operator_work_profiles", sa.Column("work_modality", sa.String(20), nullable=False, server_default="8h"))
    op.add_column("operator_work_profiles", sa.Column("bank_hours", sa.Float(), nullable=False, server_default="0"))
def downgrade():
    op.drop_column("operator_work_profiles", "bank_hours")
    op.drop_column("operator_work_profiles", "work_modality")
