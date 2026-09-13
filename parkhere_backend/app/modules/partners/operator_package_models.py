from sqlalchemy import Column, ForeignKey, Integer, String, Float, Text

from app.db.base import BaseModel


class OperatorPackageRequest(BaseModel):
    """Request to expand the operator allowance for a tenant."""
    __tablename__ = "operator_package_requests"

    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False, index=True)
    requested_by = Column(String(36), ForeignKey("users.id"), nullable=False)
    quantity = Column(Integer, nullable=False)
    package_type = Column(String(20), nullable=False, default="individual")
    amount = Column(Float, nullable=False, default=0)
    status = Column(String(24), nullable=False, default="pending_payment", index=True)
    receipt_path = Column(Text, nullable=True)
    reviewed_by = Column(String(36), ForeignKey("users.id"), nullable=True)
