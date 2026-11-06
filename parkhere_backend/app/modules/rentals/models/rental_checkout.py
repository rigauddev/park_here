from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship
from app.db.base import BaseModel

class RentalCheckout(BaseModel):
    __tablename__ = "rental_checkouts"

    reservation_id = Column(String(36), ForeignKey("rental_reservations.id"), nullable=False, index=True)
    timestamp = Column(DateTime, nullable=False)
    km = Column(Integer, nullable=True)
    photos = Column(JSON, nullable=True)  # list of URLs/base64
    items = Column(JSON, nullable=True)   # condition checklist results
    notes = Column(String, nullable=True)
    damage_fine = Column(Float, nullable=True, default=0)

    reservation = relationship("RentalReservation", back_populates="checkout")

