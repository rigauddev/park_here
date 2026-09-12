from sqlalchemy import Boolean, Column, Float, ForeignKey, String, UniqueConstraint

from app.db.base import BaseModel


class PlatformFee(BaseModel):
    __tablename__ = "platform_fees"

    service_type = Column(String(50), nullable=False, unique=True)
    fee_mode = Column(String(20), nullable=False, default="hybrid")
    fixed_amount = Column(Float, nullable=False, default=0)
    percentage = Column(Float, nullable=False, default=0)
    min_fee = Column(Float, nullable=False, default=0)
    max_fee = Column(Float, nullable=True)
    is_active = Column(Boolean, default=True)


class PartnerPlatformFee(BaseModel):
    """Per-partner override; absent rows inherit the global service fee."""
    __tablename__ = "partner_platform_fees"
    __table_args__ = (UniqueConstraint("tenant_id", "service_type", name="uq_partner_fee_tenant_service"),)

    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False, index=True)
    service_type = Column(String(50), nullable=False)
    fee_mode = Column(String(20), nullable=False, default="hybrid")
    fixed_amount = Column(Float, nullable=False, default=0)
    percentage = Column(Float, nullable=False, default=0)
    min_fee = Column(Float, nullable=False, default=0)
    max_fee = Column(Float, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
