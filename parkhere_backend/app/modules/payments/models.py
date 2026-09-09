from sqlalchemy import Boolean, Column, Float, ForeignKey, String, Text, Numeric, UniqueConstraint

from app.db.base import BaseModel


class PartnerPaymentAccount(BaseModel):
    __tablename__ = "partner_payment_accounts"

    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False)
    provider = Column(String(40), nullable=False, default="mercado_pago")
    provider_account_id = Column(String(120), nullable=False)
    account_label = Column(String(120), nullable=False)
    status = Column(String(40), nullable=False, default="pending_verification")
    is_default = Column(Boolean, default=True)
    is_active = Column(Boolean, default=True)


class PaymentTransaction(BaseModel):
    __tablename__ = "payment_transactions"

    reservation_id = Column(String(36), ForeignKey("reservations.id"), nullable=False)
    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False)
    provider = Column(String(40), nullable=False, default="mercado_pago")
    method = Column(String(30), nullable=False, default="pix")
    payment_purpose = Column(String(40), nullable=False, default="reservation")
    status = Column(String(40), nullable=False, default="pending")
    gross_amount = Column(Float, nullable=False, default=0)
    platform_fee_amount = Column(Float, nullable=False, default=0)
    customer_fee_amount = Column(Float, nullable=False, default=0)
    establishment_fee_amount = Column(Float, nullable=False, default=0)
    partner_amount = Column(Float, nullable=False, default=0)
    provider_fee_estimate = Column(Float, nullable=False, default=0)
    cash_received = Column(Numeric(12, 2), nullable=True)
    withheld_fee_amount = Column(Numeric(12, 2), nullable=False, default=0)
    currency = Column(String(3), nullable=False, default="BRL")
    checkout_url = Column(String(500), nullable=True)
    qr_code = Column(Text, nullable=True)
    external_reference = Column(String(120), nullable=False)
    provider_payment_id = Column(String(120), nullable=True)
    partner_provider_account_id = Column(String(120), nullable=True)
    split_snapshot = Column(Text, nullable=True)


class PartnerFeeDebt(BaseModel):
    __tablename__ = "partner_fee_debts"
    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False, index=True)
    reservation_id = Column(String(36), ForeignKey("reservations.id"), nullable=False)
    source_payment_id = Column(String(36), ForeignKey("payment_transactions.id"), nullable=False, unique=True)
    amount = Column(Numeric(12, 2), nullable=False)
    remaining_amount = Column(Numeric(12, 2), nullable=False)
    description = Column(String(255), nullable=False)


class PartnerFeeSettlement(BaseModel):
    __tablename__ = "partner_fee_settlements"
    __table_args__ = (UniqueConstraint("debt_id", "payment_id", name="uq_fee_debt_payment"),)
    debt_id = Column(String(36), ForeignKey("partner_fee_debts.id"), nullable=False)
    payment_id = Column(String(36), ForeignKey("payment_transactions.id"), nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)
