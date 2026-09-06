"""Walk-in registration, arrival tolerance and cash fee accounting."""
from alembic import op
import sqlalchemy as sa

revision = "4e5f6a7b8c9d"
down_revision = "3d4e5f6a7b8c"
branch_labels = None
depends_on = None


def base_columns():
    return [sa.Column("id", sa.CHAR(36), primary_key=True),
            sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False)]


def upgrade():
    op.add_column("reservations", sa.Column("walk_in_plate", sa.String(7)))
    op.add_column("reservations", sa.Column("walk_in_phone", sa.String(20)))
    op.add_column("parkings", sa.Column("arrival_tolerance_minutes", sa.Integer(), nullable=False, server_default="15"))
    op.add_column("payment_transactions", sa.Column("cash_received", sa.Numeric(12, 2)))
    op.add_column("payment_transactions", sa.Column("withheld_fee_amount", sa.Numeric(12, 2), nullable=False, server_default="0"))
    op.create_table("partner_fee_debts", *base_columns(),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("reservation_id", sa.String(36), sa.ForeignKey("reservations.id"), nullable=False),
        sa.Column("source_payment_id", sa.String(36), sa.ForeignKey("payment_transactions.id"), nullable=False, unique=True),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("remaining_amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("description", sa.String(255), nullable=False))
    op.create_index("ix_partner_fee_debts_tenant_id", "partner_fee_debts", ["tenant_id"])
    op.create_table("partner_fee_settlements", *base_columns(),
        sa.Column("debt_id", sa.String(36), sa.ForeignKey("partner_fee_debts.id"), nullable=False),
        sa.Column("payment_id", sa.String(36), sa.ForeignKey("payment_transactions.id"), nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.UniqueConstraint("debt_id", "payment_id", name="uq_fee_debt_payment"))


def downgrade():
    op.drop_table("partner_fee_settlements")
    op.drop_table("partner_fee_debts")
    op.drop_column("payment_transactions", "withheld_fee_amount")
    op.drop_column("payment_transactions", "cash_received")
    op.drop_column("parkings", "arrival_tolerance_minutes")
    op.drop_column("reservations", "walk_in_phone")
    op.drop_column("reservations", "walk_in_plate")
