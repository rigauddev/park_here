"""add vehicle condition and mileage based maintenance fields"""

from alembic import op
import sqlalchemy as sa


revision = "gw3x4y5z6a7b"
down_revision = "gv2w3x4y5z6a"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("rental_vehicles", sa.Column("vehicle_condition", sa.String(12), nullable=False, server_default="new"))
    op.add_column("rental_vehicles", sa.Column("current_odometer", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("rental_vehicles", sa.Column("last_service_odometer", sa.Integer(), nullable=True))
    op.add_column("rental_maintenances", sa.Column("interval_km", sa.Integer(), nullable=True))
    op.add_column("rental_maintenances", sa.Column("next_due_odometer", sa.Integer(), nullable=True))
    op.add_column("rental_maintenances", sa.Column("parts", sa.JSON(), nullable=True))
    op.add_column("rental_maintenances", sa.Column("incident", sa.Text(), nullable=True))
    op.alter_column("rental_vehicles", "vehicle_condition", server_default=None)
    op.alter_column("rental_vehicles", "current_odometer", server_default=None)


def downgrade():
    op.drop_column("rental_maintenances", "incident")
    op.drop_column("rental_maintenances", "parts")
    op.drop_column("rental_maintenances", "next_due_odometer")
    op.drop_column("rental_maintenances", "interval_km")
    op.drop_column("rental_vehicles", "last_service_odometer")
    op.drop_column("rental_vehicles", "current_odometer")
    op.drop_column("rental_vehicles", "vehicle_condition")
