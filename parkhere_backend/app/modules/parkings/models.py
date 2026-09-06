from sqlalchemy import Boolean, Column, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.db.base import BaseModel


class Parking(BaseModel):
    __tablename__ = "parkings"

    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False)
    name = Column(String(255), nullable=False)
    address = Column(String(255), nullable=False)
    city = Column(String(120), nullable=False, default="Valenca")
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    rating = Column(Float, default=5.0)
    arrival_tolerance_minutes = Column(Integer, nullable=False, default=15)
    total_spots = Column(Integer, nullable=False, default=0)
    available_spots = Column(Integer, nullable=False, default=0)
    covered_spots = Column(Integer, nullable=False, default=0)
    uncovered_spots = Column(Integer, nullable=False, default=0)
    vip_spots = Column(Integer, nullable=False, default=0)
    large_spots = Column(Integer, nullable=False, default=0)
    bus_spots = Column(Integer, nullable=False, default=0)
    pickup_spots = Column(Integer, nullable=False, default=0)
    first_hour_price = Column(Float, nullable=False, default=0)
    additional_hour_price = Column(Float, nullable=False, default=0)
    daily_price = Column(Float, nullable=False, default=0)
    weekly_price = Column(Float, nullable=False, default=0)
    monthly_price = Column(Float, nullable=False, default=0)
    covered_first_hour_price = Column(Float, nullable=False, default=0)
    covered_additional_hour_price = Column(Float, nullable=False, default=0)
    covered_daily_price = Column(Float, nullable=False, default=0)
    covered_weekly_price = Column(Float, nullable=False, default=0)
    covered_monthly_price = Column(Float, nullable=False, default=0)
    uncovered_first_hour_price = Column(Float, nullable=False, default=0)
    uncovered_additional_hour_price = Column(Float, nullable=False, default=0)
    uncovered_daily_price = Column(Float, nullable=False, default=0)
    uncovered_weekly_price = Column(Float, nullable=False, default=0)
    uncovered_monthly_price = Column(Float, nullable=False, default=0)
    has_covered_area = Column(Boolean, default=False)
    has_vip_spots = Column(Boolean, default=False)
    has_24h_gate = Column(Boolean, default=False)
    has_security_system = Column(Boolean, default=False)
    wants_automatic_access = Column(Boolean, default=False)
    has_automatic_access = Column(Boolean, default=False)
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
