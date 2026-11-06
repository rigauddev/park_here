from sqlalchemy import Boolean, Column, Float, ForeignKey, String
from sqlalchemy.orm import relationship
from app.db.base import BaseModel

class RentalCompany(BaseModel):
    __tablename__ = "rental_companies"
    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False, index=True)
    parent_parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=True, index=True)
    service_type = Column(String(40), nullable=False, default="vehicle_rental")
    unit_kind = Column(String(20), nullable=False, default="branch")
    name = Column(String(120), nullable=False)
    address = Column(String(200), nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    cnpj = Column(String(20), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    vehicles = relationship("RentalVehicle", back_populates="company")
