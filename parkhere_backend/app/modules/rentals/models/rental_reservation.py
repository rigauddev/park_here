from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship
from app.db.base import BaseModel

class RentalReservation(BaseModel):
    __tablename__ = "rental_reservations"
    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False, index=True)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    company_id = Column(String(36), ForeignKey("rental_companies.id"), nullable=False, index=True)
    vehicle_id = Column(String(36), ForeignKey("rental_vehicles.id"), nullable=False, index=True)
    plan_id = Column(String(36), ForeignKey("rental_plans.id"), nullable=True, index=True)
    start_date = Column(DateTime(timezone=True), nullable=False)
    end_date = Column(DateTime(timezone=True), nullable=False)
    total_price = Column(Float, nullable=False)
    status = Column(String(24), nullable=False, default="pending")
    extras = Column(Text, nullable=True)
    km_start = Column(Integer, nullable=True)
    km_end = Column(Integer, nullable=True)
    company = relationship("RentalCompany")
    vehicle = relationship("RentalVehicle")
    plan = relationship("RentalPlan")
    checkin = relationship("RentalCheckin", back_populates="reservation", uselist=False)
    checkout = relationship("RentalCheckout", back_populates="reservation", uselist=False)
