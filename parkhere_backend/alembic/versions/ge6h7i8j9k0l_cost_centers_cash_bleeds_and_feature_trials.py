"""Add cost centers, manual financial entries, cash bleeds, and feature trial fields.

Revision ID: ge6h7i8j9k0l
Revises: gd5g6h7i8j9k
Create Date: 2026-10-31 12:30:00.000000
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.engine.reflection import Inspector

revision = "ge6h7i8j9k0l"
down_revision = "gd5g6h7i8j9k"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = Inspector.from_engine(conn)
    existing_tables = set(inspector.get_table_names())

    # 1. Table: partner_cash_bleeds (Sangrias de caixa)
    if "partner_cash_bleeds" not in existing_tables:
        op.create_table(
            "partner_cash_bleeds",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id"), nullable=False, index=True),
            sa.Column("parking_id", sa.String(36), sa.ForeignKey("parkings.id"), nullable=False, index=True),
            sa.Column("cash_session_id", sa.String(36), nullable=True),
            sa.Column("operator_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
            sa.Column("operator_name", sa.String(120), nullable=False),
            sa.Column("target_type", sa.String(30), nullable=False, server_default="convenience"),
            sa.Column("amount", sa.Float(), nullable=False),
            sa.Column("reason", sa.String(255), nullable=False),
            sa.Column("notes", sa.Text(), nullable=True),
        )

    # 2. Table: financial_cost_centers (Centros de custo)
    if "financial_cost_centers" not in existing_tables:
        op.create_table(
            "financial_cost_centers",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id"), nullable=False, index=True),
            sa.Column("parking_id", sa.String(36), sa.ForeignKey("parkings.id"), nullable=True, index=True),
            sa.Column("name", sa.String(120), nullable=False),
            sa.Column("code", sa.String(30), nullable=True),
            sa.Column("type", sa.String(30), nullable=False, server_default="both"),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default="1"),
        )

    # 3. Table: financial_entries (Lançamentos manuais de Entrada e Saída)
    if "financial_entries" not in existing_tables:
        op.create_table(
            "financial_entries",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id"), nullable=False, index=True),
            sa.Column("parking_id", sa.String(36), sa.ForeignKey("parkings.id"), nullable=True, index=True),
            sa.Column("cost_center_id", sa.String(36), sa.ForeignKey("financial_cost_centers.id"), nullable=True, index=True),
            sa.Column("created_by_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
            sa.Column("created_by_name", sa.String(120), nullable=False),
            sa.Column("entry_type", sa.String(20), nullable=False),  # "income" ou "expense"
            sa.Column("category", sa.String(80), nullable=False),
            sa.Column("description", sa.String(255), nullable=False),
            sa.Column("amount", sa.Float(), nullable=False),
            sa.Column("payment_method", sa.String(30), nullable=False, server_default="cash"),
            sa.Column("entry_date", sa.DateTime(timezone=True), nullable=False),
            sa.Column("status", sa.String(20), nullable=False, server_default="completed"),
            sa.Column("notes", sa.Text(), nullable=True),
        )

    # 4. Columns on partner_feature_entitlements for Trial & Split Billing
    existing_entitlements_cols = {col["name"] for col in inspector.get_columns("partner_feature_entitlements")}
    if "trial_ends_at" not in existing_entitlements_cols:
        op.add_column(
            "partner_feature_entitlements",
            sa.Column("trial_ends_at", sa.DateTime(timezone=True), nullable=True),
        )
    if "is_trial" not in existing_entitlements_cols:
        op.add_column(
            "partner_feature_entitlements",
            sa.Column("is_trial", sa.Boolean(), nullable=False, server_default="0"),
        )
    if "billing_modality" not in existing_entitlements_cols:
        op.add_column(
            "partner_feature_entitlements",
            sa.Column("billing_modality", sa.String(30), nullable=False, server_default="direct_debit"),
        )
    if "accumulated_debt" not in existing_entitlements_cols:
        op.add_column(
            "partner_feature_entitlements",
            sa.Column("accumulated_debt", sa.Float(), nullable=False, server_default="0"),
        )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = Inspector.from_engine(conn)
    existing_tables = set(inspector.get_table_names())
    existing_entitlements_cols = {col["name"] for col in inspector.get_columns("partner_feature_entitlements")}

    if "accumulated_debt" in existing_entitlements_cols:
        op.drop_column("partner_feature_entitlements", "accumulated_debt")
    if "billing_modality" in existing_entitlements_cols:
        op.drop_column("partner_feature_entitlements", "billing_modality")
    if "is_trial" in existing_entitlements_cols:
        op.drop_column("partner_feature_entitlements", "is_trial")
    if "trial_ends_at" in existing_entitlements_cols:
        op.drop_column("partner_feature_entitlements", "trial_ends_at")

    if "financial_entries" in existing_tables:
        op.drop_table("financial_entries")
    if "financial_cost_centers" in existing_tables:
        op.drop_table("financial_cost_centers")
    if "partner_cash_bleeds" in existing_tables:
        op.drop_table("partner_cash_bleeds")

