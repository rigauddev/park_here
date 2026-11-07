"""add rental vehicle registration fields and crlv document"""
from alembic import op
import sqlalchemy as sa

revision = "gu1u2v3w4x5y"
down_revision = "gt9u1v2w3x4y"
branch_labels = None
depends_on = None

def upgrade():
    op.add_column("rental_vehicles", sa.Column("manufacture_year", sa.Integer(), nullable=True))
    op.add_column("rental_vehicles", sa.Column("crlv_code", sa.String(length=40), nullable=True))
    op.add_column("rental_vehicles", sa.Column("renavam", sa.String(length=20), nullable=True))
    op.add_column("rental_vehicles", sa.Column("chassis", sa.String(length=40), nullable=True))
    op.add_column("rental_vehicles", sa.Column("crlv_file_url", sa.String(length=500), nullable=True))

def downgrade():
    op.drop_column("rental_vehicles", "crlv_file_url")
    op.drop_column("rental_vehicles", "chassis")
    op.drop_column("rental_vehicles", "renavam")
    op.drop_column("rental_vehicles", "crlv_code")
    op.drop_column("rental_vehicles", "manufacture_year")
