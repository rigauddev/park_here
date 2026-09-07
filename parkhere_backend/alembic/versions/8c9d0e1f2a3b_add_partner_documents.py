"""add partner document uploads"""

from alembic import op
import sqlalchemy as sa

revision = '8c9d0e1f2a3b'
down_revision = '7b8c9d0e1f2a'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'partner_documents',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.Column('tenant_id', sa.String(36), sa.ForeignKey('tenants.id'), nullable=False),
        sa.Column('document_type', sa.String(20), nullable=False),
        sa.Column('file_name', sa.String(255), nullable=False),
        sa.Column('storage_path', sa.String(500), nullable=False),
    )


def downgrade() -> None:
    op.drop_table('partner_documents')
