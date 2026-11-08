from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import relationship

from app.db.base import BaseModel


class RentalMaintenance(BaseModel):
    __tablename__ = "rental_maintenances"

    vehicle_id = Column(String(36), ForeignKey("rental_vehicles.id"), nullable=False, index=True)
    maintenance_type = Column(String(40), nullable=False)
    description = Column(Text, nullable=True)
    performed_at = Column(DateTime(timezone=True), nullable=False)
    next_due_at = Column(DateTime(timezone=True), nullable=True)
    odometer = Column(Integer, nullable=True)
    interval_km = Column(Integer, nullable=True)
    next_due_odometer = Column(Integer, nullable=True)
    cost = Column(Float, nullable=True)
    parts = Column(JSON, nullable=True)
    incident = Column(Text, nullable=True)
    status = Column(String(20), nullable=False, default="completed")

    vehicle = relationship("RentalVehicle")
