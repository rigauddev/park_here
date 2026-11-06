from sqlalchemy import Boolean, Column, Float, ForeignKey, Integer, JSON, String
from sqlalchemy.orm import relationship
from app.db.base import BaseModel

class RentalVehicle(BaseModel):
    __tablename__ = "rental_vehicles"
    company_id = Column(String(36), ForeignKey("rental_companies.id"), nullable=False, index=True)
    vehicle_type = Column(String(30), nullable=False, default="car")
    model = Column(String(120), nullable=False)
    brand = Column(String(80), nullable=False)
    price_per_day = Column(Float, nullable=False)
    status = Column(String(20), nullable=False, default="available")
    plate = Column(String(20), nullable=True)
    year = Column(Integer, nullable=True)
    photo_urls = Column(JSON, nullable=True)
    specifications = Column(JSON, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    company = relationship("RentalCompany", back_populates="vehicles")
