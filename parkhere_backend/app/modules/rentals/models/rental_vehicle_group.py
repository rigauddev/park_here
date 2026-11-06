from sqlalchemy import Boolean, Column, Float, ForeignKey, String, Text
from sqlalchemy.orm import relationship

from app.db.base import BaseModel


class RentalVehicleGroup(BaseModel):
    """Commercial category used by rental plans (ACRISS-like grouping)."""

    __tablename__ = "rental_vehicle_groups"

    company_id = Column(String(36), ForeignKey("rental_companies.id"), nullable=False, index=True)
    name = Column(String(120), nullable=False)
    code = Column(String(20), nullable=True)
    vehicle_type = Column(String(30), nullable=False, default="car")
    description = Column(Text, nullable=True)
    suggested_price_per_day = Column(Float, nullable=True)
    is_default = Column(Boolean, nullable=False, default=False)
    is_active = Column(Boolean, nullable=False, default=True)

    company = relationship("RentalCompany")
