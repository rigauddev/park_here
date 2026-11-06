from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, String, Text
from sqlalchemy.orm import relationship

from app.db.base import BaseModel


class FinancialCostCenter(BaseModel):
    __tablename__ = "financial_cost_centers"

    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False, index=True)
    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=True, index=True)
    name = Column(String(120), nullable=False)
    code = Column(String(30), nullable=True)
    type = Column(String(30), nullable=False, default="both")  # expense, revenue, both
    is_active = Column(Boolean, nullable=False, default=True)


class FinancialEntry(BaseModel):
    __tablename__ = "financial_entries"

    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False, index=True)
    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=True, index=True)
    cost_center_id = Column(String(36), ForeignKey("financial_cost_centers.id"), nullable=True, index=True)
    created_by_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    created_by_name = Column(String(120), nullable=False)
    entry_type = Column(String(20), nullable=False)  # income ou expense
    category = Column(String(80), nullable=False)
    description = Column(String(255), nullable=False)
    amount = Column(Float, nullable=False)
    payment_method = Column(String(30), nullable=False, default="cash")
    entry_date = Column(DateTime(timezone=True), nullable=False)
    status = Column(String(20), nullable=False, default="completed")
    notes = Column(Text, nullable=True)

    cost_center = relationship("FinancialCostCenter")

