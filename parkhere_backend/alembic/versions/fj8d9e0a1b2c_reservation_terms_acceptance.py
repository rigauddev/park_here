"""Persist versioned service-specific reservation terms acceptance."""
from alembic import op
import sqlalchemy as sa

revision = "fj8d9e0a1b2c"
down_revision = "fh7c8d9e0a1b"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("reservations", sa.Column("terms_accepted_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("reservations", sa.Column("terms_version", sa.String(length=40), nullable=True))
    op.add_column("reservations", sa.Column("terms_locale", sa.String(length=10), nullable=True))
    op.add_column("reservations", sa.Column("accepted_terms_snapshot", sa.Text(), nullable=True))


def downgrade():
    op.drop_column("reservations", "accepted_terms_snapshot")
    op.drop_column("reservations", "terms_locale")
    op.drop_column("reservations", "terms_version")
    op.drop_column("reservations", "terms_accepted_at")
