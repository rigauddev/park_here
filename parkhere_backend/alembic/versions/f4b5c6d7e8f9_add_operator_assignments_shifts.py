"""associate operators with parking units and shifts"""
from alembic import op
import sqlalchemy as sa

revision = "f4b5c6d7e8f9"
down_revision = "f3a4b5c6d7e8"
branch_labels = None
depends_on = None

def upgrade():
    op.create_table(
        "operator_parking_assignments",
        sa.Column("operator_id", sa.String(36), nullable=False),
        sa.Column("parking_id", sa.String(36), nullable=False),
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["operator_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["parking_id"], ["parkings.id"]),
        sa.UniqueConstraint("operator_id", "parking_id"),
    )
    op.create_table(
        "operator_work_shifts",
        sa.Column("operator_id", sa.String(36), nullable=False),
        sa.Column("parking_id", sa.String(36), nullable=False),
        sa.Column("starts_at", sa.DateTime(), nullable=False),
        sa.Column("ends_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["operator_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["parking_id"], ["parkings.id"]),
    )

def downgrade():
    op.drop_table("operator_work_shifts")
    op.drop_table("operator_parking_assignments")
