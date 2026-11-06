from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, JSON, String
from sqlalchemy.orm import relationship
from app.db.base import BaseModel

class RentalCheckout(BaseModel):
    __tablename__ = "rental_checkouts"
    reservation_id = Column(String(36), ForeignKey("rental_reservations.id"), nullable=False, unique=True, index=True)
    timestamp = Column(DateTime(timezone=True), nullable=False)
    km = Column(Integer, nullable=True)
    photos = Column(JSON, nullable=True)
    items = Column(JSON, nullable=True)
    notes = Column(String(1000), nullable=True)
    damage_fine = Column(Float, nullable=False, default=0)
    reservation = relationship("RentalReservation", back_populates="checkout")
