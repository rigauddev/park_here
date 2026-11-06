from sqlalchemy import Column, DateTime, ForeignKey, Integer, JSON, String
from sqlalchemy.orm import relationship
from app.db.base import BaseModel

class RentalCheckin(BaseModel):
    __tablename__ = "rental_checkins"
    reservation_id = Column(String(36), ForeignKey("rental_reservations.id"), nullable=False, unique=True, index=True)
    timestamp = Column(DateTime(timezone=True), nullable=False)
    km = Column(Integer, nullable=True)
    photos = Column(JSON, nullable=True)
    items = Column(JSON, nullable=True)
    notes = Column(String(1000), nullable=True)
    reservation = relationship("RentalReservation", back_populates="checkin")
