from sqlalchemy import Boolean, Column, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.db.base import BaseModel


class Parking(BaseModel):
    __tablename__ = "parkings"

    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False)
    name = Column(String(255), nullable=False)
    address = Column(String(255), nullable=False)
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    rating = Column(Float, default=5.0)
    total_spots = Column(Integer, nullable=False, default=0)
    available_spots = Column(Integer, nullable=False, default=0)
    first_hour_price = Column(Float, nullable=False, default=0)
    additional_hour_price = Column(Float, nullable=False, default=0)
    daily_price = Column(Float, nullable=False, default=0)
    monthly_price = Column(Float, nullable=False, default=0)
    has_covered_area = Column(Boolean, default=False)
    has_vip_spots = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)

    services = relationship("ParkingService", back_populates="parking")


class ParkingService(BaseModel):
    __tablename__ = "parking_services"

    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=False)
    code = Column(String(50), nullable=False)
    name = Column(String(120), nullable=False)
    price = Column(Float, nullable=False, default=0)
    is_active = Column(Boolean, default=True)

    parking = relationship("Parking", back_populates="services")
