"""store partner payout identity and Pix verification state

Revision ID: fu8f9a0b1c2d
Revises: ft7e8f9a0b1c
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "fu8f9a0b1c2d"
down_revision: Union[str, Sequence[str], None] = "ft7e8f9a0b1c"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("partner_payment_accounts", sa.Column("pix_key", sa.String(120), nullable=True))
    op.add_column("partner_payment_accounts", sa.Column("account_holder_name", sa.String(160), nullable=True))
    op.add_column("partner_payment_accounts", sa.Column("account_holder_document", sa.String(20), nullable=True))
    op.add_column(
        "partner_payment_accounts",
        sa.Column("verification_status", sa.String(40), nullable=False, server_default="pending_provider_verification"),
    )


def downgrade() -> None:
    op.drop_column("partner_payment_accounts", "verification_status")
    op.drop_column("partner_payment_accounts", "account_holder_document")
    op.drop_column("partner_payment_accounts", "account_holder_name")
    op.drop_column("partner_payment_accounts", "pix_key")
