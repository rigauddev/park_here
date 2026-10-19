from sqlalchemy import Boolean, Column, ForeignKey, String, Text, UniqueConstraint

from app.db.base import BaseModel


class PartnerPermissionProfile(BaseModel):
    __tablename__ = "partner_permission_profiles"
    __table_args__ = (UniqueConstraint("tenant_id", "name", name="uq_partner_permission_profile_name"),)

    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False, index=True)
    name = Column(String(100), nullable=False)
    permissions = Column(Text, nullable=False, default="[]")
    is_active = Column(Boolean, nullable=False, default=True)
