from sqlalchemy import Column, String, Float, DateTime, ForeignKey, Integer, Boolean
from sqlalchemy.orm import relationship
from app.db.base import BaseModel

class RentalReservation(BaseModel):
    __tablename__ = "rental_reservations"

    partner_id = Column(String(36), ForeignKey("partners.id"), nullable=False, index=True)
    company_id = Column(String(36), ForeignKey("rental_companies.id"), nullable=False, index=True)
    vehicle_id = Column(String(36), ForeignKey("vehicles.id"), nullable=False, index=True)
    start_date = Column(DateTime, nullable=False)
    end_date = Column(DateTime, nullable=False)
    total_price = Column(Float, nullable=False)
    status = Column(String(20), nullable=False, default="pending")  # pending, confirmed, cancelled, completed
    extras = Column(String, nullable=True)  # JSON string for optional items (e.g., "cadeirinha", "tanque cheio")
    km_start = Column(Integer, nullable=True)
    km_end = Column(Integer, nullable=True)
    created_at = Column(DateTime, nullable=False)
    updated_at = Column(DateTime, nullable=False)

    company = relationship("RentalCompany")
    vehicle = relationship("Vehicle")
    partner = relationship("Partner")

