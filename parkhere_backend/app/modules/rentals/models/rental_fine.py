from sqlalchemy import Column, DateTime, Float, ForeignKey, String, Text
from sqlalchemy.orm import relationship

from app.db.base import BaseModel


class RentalFine(BaseModel):
    __tablename__ = "rental_fines"

    reservation_id = Column(String(36), ForeignKey("rental_reservations.id"), nullable=False, index=True)
    vehicle_id = Column(String(36), ForeignKey("rental_vehicles.id"), nullable=False, index=True)
    fine_type = Column(String(40), nullable=False)
    occurred_at = Column(DateTime(timezone=True), nullable=False)
    amount = Column(Float, nullable=False)
    status = Column(String(20), nullable=False, default="pending")
    evidence_url = Column(String(500), nullable=True)
    notes = Column(Text, nullable=True)

    reservation = relationship("RentalReservation")
    vehicle = relationship("RentalVehicle")
