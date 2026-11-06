"""add rental vehicle groups

Revision ID: gn4o5p6q7r8s
Revises: gm3n4o5p6q7r
"""
from alembic import op
import sqlalchemy as sa

revision = 'gn4o5p6q7r8s'
down_revision = 'gm3n4o5p6q7r'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'rental_vehicle_groups',
        sa.Column('company_id', sa.String(length=36), nullable=False),
        sa.Column('name', sa.String(length=120), nullable=False),
        sa.Column('code', sa.String(length=20), nullable=True),
        sa.Column('vehicle_type', sa.String(length=30), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('suggested_price_per_day', sa.Float(), nullable=True),
        sa.Column('is_default', sa.Boolean(), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('id', sa.CHAR(length=36), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['company_id'], ['rental_companies.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_rental_vehicle_groups_company_id', 'rental_vehicle_groups', ['company_id'])
    op.add_column('rental_vehicles', sa.Column('group_id', sa.String(length=36), nullable=True))
    op.create_index('ix_rental_vehicles_group_id', 'rental_vehicles', ['group_id'])
    op.create_foreign_key('fk_rental_vehicles_group_id', 'rental_vehicles', 'rental_vehicle_groups', ['group_id'], ['id'])
    op.add_column('rental_plans', sa.Column('group_id', sa.String(length=36), nullable=True))
    op.create_index('ix_rental_plans_group_id', 'rental_plans', ['group_id'])
    op.create_foreign_key('fk_rental_plans_group_id', 'rental_plans', 'rental_vehicle_groups', ['group_id'], ['id'])


def downgrade():
    op.drop_constraint('fk_rental_plans_group_id', 'rental_plans', type_='foreignkey')
    op.drop_index('ix_rental_plans_group_id', table_name='rental_plans')
    op.drop_column('rental_plans', 'group_id')
    op.drop_constraint('fk_rental_vehicles_group_id', 'rental_vehicles', type_='foreignkey')
    op.drop_index('ix_rental_vehicles_group_id', table_name='rental_vehicles')
    op.drop_column('rental_vehicles', 'group_id')
    op.drop_index('ix_rental_vehicle_groups_company_id', table_name='rental_vehicle_groups')
    op.drop_table('rental_vehicle_groups')
