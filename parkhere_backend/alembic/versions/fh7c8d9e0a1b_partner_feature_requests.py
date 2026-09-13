"""persist partner requests for paid feature activation

Revision ID: fh7c8d9e0a1b
Revises: fg6b7c8d9e0a
"""
from alembic import op
import sqlalchemy as sa

revision = 'fh7c8d9e0a1b'
down_revision = 'fg6b7c8d9e0a'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'partner_feature_requests',
        sa.Column('tenant_id', sa.String(length=36), nullable=False),
        sa.Column('feature_key', sa.String(length=80), nullable=False),
        sa.Column('requested_by', sa.String(length=36), nullable=False),
        sa.Column('quantity', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('capacity_after', sa.Integer(), nullable=True),
        sa.Column('unit_price', sa.Float(), nullable=False, server_default='0'),
        sa.Column('total_price', sa.Float(), nullable=False, server_default='0'),
        sa.Column('billing_period', sa.String(length=20), nullable=False, server_default='one_time'),
        sa.Column('status', sa.String(length=30), nullable=False, server_default='pending_review'),
        sa.Column('notes', sa.String(length=500), nullable=True),
        sa.Column('reviewed_by', sa.String(length=36), nullable=True),
        sa.Column('reviewed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('id', sa.CHAR(length=36), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id']),
        sa.ForeignKeyConstraint(['requested_by'], ['users.id']),
        sa.ForeignKeyConstraint(['reviewed_by'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_partner_feature_requests_tenant_id', 'partner_feature_requests', ['tenant_id'])
    op.create_index('ix_partner_feature_requests_feature_key', 'partner_feature_requests', ['feature_key'])
    op.create_index('ix_partner_feature_requests_status', 'partner_feature_requests', ['status'])


def downgrade():
    op.drop_index('ix_partner_feature_requests_status', table_name='partner_feature_requests')
    op.drop_index('ix_partner_feature_requests_feature_key', table_name='partner_feature_requests')
    op.drop_index('ix_partner_feature_requests_tenant_id', table_name='partner_feature_requests')
    op.drop_table('partner_feature_requests')
