from sqlalchemy import Boolean, Column, Float, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import relationship

from app.db.base import BaseModel


class RentalPlan(BaseModel):
    """Commercial plan offered for one rental company."""

    __tablename__ = "rental_plans"

    company_id = Column(String(36), ForeignKey("rental_companies.id"), nullable=False, index=True)
    group_id = Column(String(36), ForeignKey("rental_vehicle_groups.id"), nullable=True, index=True)
    name = Column(String(120), nullable=False)
    description = Column(Text, nullable=True)
    vehicle_type = Column(String(30), nullable=True)
    price_per_day = Column(Float, nullable=False)
    price_per_week = Column(Float, nullable=True)
    price_per_month = Column(Float, nullable=True)
    deposit_amount = Column(Float, nullable=False, default=0)
    included_items = Column(JSON, nullable=True)
    mileage_limit_per_day = Column(Integer, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)

    company = relationship("RentalCompany")
