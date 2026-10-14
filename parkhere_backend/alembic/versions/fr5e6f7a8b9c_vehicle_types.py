"""Add motorcycle and bicycle asset metadata."""
from alembic import op
import sqlalchemy as sa

revision = "fr5e6f7a8b9c"
down_revision = "fq4d5e6f7a8b"
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    columns = {column["name"] for column in inspector.get_columns("vehicles")}
    if "vehicle_type" not in columns:
        op.add_column("vehicles", sa.Column("vehicle_type", sa.String(20), nullable=True, server_default="car"))
    if "bicycle_parts" not in columns:
        op.add_column("vehicles", sa.Column("bicycle_parts", sa.String(500), nullable=True))
    op.execute("UPDATE vehicles SET vehicle_type = 'car' WHERE vehicle_type IS NULL")
    op.alter_column(
        "vehicles",
        "vehicle_type",
        existing_type=sa.String(20),
        nullable=False,
        server_default="car",
    )


def downgrade() -> None:
    op.drop_column("vehicles", "bicycle_parts")
    op.drop_column("vehicles", "vehicle_type")
