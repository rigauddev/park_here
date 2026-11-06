"""Store masked card display metadata in customer wallet records.

Revision ID: fm1b2c3d4e5f
Revises: fl1b2c3d4e5f
"""
from alembic import op
import sqlalchemy as sa


revision = "fm1b2c3d4e5f"
down_revision = "fl1b2c3d4e5f"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("wallet_payment_methods", sa.Column("card_brand", sa.String(length=40), nullable=True))
    op.add_column("wallet_payment_methods", sa.Column("cardholder_name", sa.String(length=120), nullable=True))
    op.add_column("wallet_payment_methods", sa.Column("expiration_month", sa.Integer(), nullable=True))
    op.add_column("wallet_payment_methods", sa.Column("expiration_year", sa.Integer(), nullable=True))


def downgrade():
    op.drop_column("wallet_payment_methods", "expiration_year")
    op.drop_column("wallet_payment_methods", "expiration_month")
    op.drop_column("wallet_payment_methods", "cardholder_name")
    op.drop_column("wallet_payment_methods", "card_brand")
