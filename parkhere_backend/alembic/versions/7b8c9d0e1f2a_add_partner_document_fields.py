"""add cpf/cnpj fields to partner profiles"""

from alembic import op
import sqlalchemy as sa

revision = "7b8c9d0e1f2a"
down_revision = "6a7b8c9d0e1f"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("partner_profiles", sa.Column("document_type", sa.String(10), nullable=True))
    op.add_column("partner_profiles", sa.Column("document_number", sa.String(20), nullable=True))


def downgrade() -> None:
    op.drop_column("partner_profiles", "document_number")
    op.drop_column("partner_profiles", "document_type")
