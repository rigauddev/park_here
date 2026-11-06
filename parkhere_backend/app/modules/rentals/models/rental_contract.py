from sqlalchemy import Column, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import relationship

from app.db.base import BaseModel


class RentalContract(BaseModel):
    __tablename__ = "rental_contracts"

    reservation_id = Column(String(36), ForeignKey("rental_reservations.id"), nullable=False, unique=True, index=True)
    version = Column(String(30), nullable=False, default="mvp-1")
    terms_text = Column(Text, nullable=False)
    status = Column(String(20), nullable=False, default="pending")
    customer_accepted_at = Column(DateTime(timezone=True), nullable=True)
    partner_accepted_at = Column(DateTime(timezone=True), nullable=True)
    pdf_path = Column(String(500), nullable=True)

    reservation = relationship("RentalReservation")
