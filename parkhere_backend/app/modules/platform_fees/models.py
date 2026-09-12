from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint

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


class ParkingPlatformFee(BaseModel):
    """A unit-specific rate overrides partner-wide and global defaults."""
    __tablename__ = "parking_platform_fees"
    __table_args__ = (UniqueConstraint("parking_id", "service_type", name="uq_parking_fee_unit_service"),)

    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False, index=True)
    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=False, index=True)
    service_type = Column(String(50), nullable=False)
    fee_mode = Column(String(20), nullable=False, default="hybrid")
    fixed_amount = Column(Float, nullable=False, default=0)
    percentage = Column(Float, nullable=False, default=0)
    min_fee = Column(Float, nullable=False, default=0)
    max_fee = Column(Float, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)


class PartnerFeatureEntitlement(BaseModel):
    __tablename__ = "partner_feature_entitlements"
    __table_args__ = (UniqueConstraint("tenant_id", "feature_key", name="uq_partner_feature_tenant_key"),)

    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False, index=True)
    feature_key = Column(String(80), nullable=False)
    is_enabled = Column(Boolean, nullable=False, default=False)
    is_paid = Column(Boolean, nullable=False, default=False)
    price = Column(Float, nullable=False, default=0)
    billing_period = Column(String(20), nullable=False, default="monthly")
    notes = Column(String(500), nullable=True)


class PartnerFeatureRequest(BaseModel):
    __tablename__ = 'partner_feature_requests'

    tenant_id = Column(String(36), ForeignKey('tenants.id'), nullable=False, index=True)
    feature_key = Column(String(80), nullable=False, index=True)
    requested_by = Column(String(36), ForeignKey('users.id'), nullable=False)
    quantity = Column(Integer, nullable=False, default=1)
    capacity_after = Column(Integer, nullable=True)
    unit_price = Column(Float, nullable=False, default=0)
    total_price = Column(Float, nullable=False, default=0)
    billing_period = Column(String(20), nullable=False, default='one_time')
    status = Column(String(30), nullable=False, default='pending_review', index=True)
    notes = Column(String(500), nullable=True)
    reviewed_by = Column(String(36), ForeignKey('users.id'), nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)


class EmailTemplate(BaseModel):
    __tablename__ = "email_templates"
    __table_args__ = (UniqueConstraint("template_key", "locale", name="uq_email_template_key_locale"),)

    template_key = Column(String(80), nullable=False)
    locale = Column(String(10), nullable=False, default="pt_BR")
    display_name = Column(String(120), nullable=False)
    subject = Column(String(255), nullable=False)
    header_html = Column(Text, nullable=False)
    body_html = Column(Text, nullable=False)
    footer_html = Column(Text, nullable=False)
    is_active = Column(Boolean, nullable=False, default=True)


class AdminAuditLog(BaseModel):
    __tablename__ = "admin_audit_logs"

    actor_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=True, index=True)
    action = Column(String(80), nullable=False, index=True)
    target_type = Column(String(80), nullable=False)
    target_id = Column(String(36), nullable=False, index=True)
    details = Column(Text, nullable=True)
