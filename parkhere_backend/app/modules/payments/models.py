from sqlalchemy import Boolean, Column, Float, ForeignKey, String, Text

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
    partner_amount = Column(Float, nullable=False, default=0)
    provider_fee_estimate = Column(Float, nullable=False, default=0)
    currency = Column(String(3), nullable=False, default="BRL")
    checkout_url = Column(String(500), nullable=True)
    qr_code = Column(Text, nullable=True)
    external_reference = Column(String(120), nullable=False)
    provider_payment_id = Column(String(120), nullable=True)
    partner_provider_account_id = Column(String(120), nullable=True)
    split_snapshot = Column(Text, nullable=True)
