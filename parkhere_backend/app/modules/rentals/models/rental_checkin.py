from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship
from app.db.base import BaseModel

class RentalCheckin(BaseModel):
    __tablename__ = "rental_checkins"

    reservation_id = Column(String(36), ForeignKey("rental_reservations.id"), nullable=False, index=True)
    timestamp = Column(DateTime, nullable=False)
    km = Column(Integer, nullable=True)
    photos = Column(JSON, nullable=True)  # list of URLs or base64 strings
    items = Column(JSON, nullable=True)   # optional items selected (e.g., "cadeirinha": true)
    notes = Column(String, nullable=True)

    reservation = relationship("RentalReservation", back_populates="checkin")

