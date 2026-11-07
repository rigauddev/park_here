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
    # Price snapshot: the customer fee is added to the amount paid by the
    # customer, while the establishment fee is withheld from the partner
    # payout. Both values are frozen when the reservation is created.
    base_amount = Column(Float, nullable=False, default=0)
    customer_fee_amount = Column(Float, nullable=False, default=0)
    establishment_fee_amount = Column(Float, nullable=False, default=0)
    platform_fee_amount = Column(Float, nullable=False, default=0)
    final_total = Column(Float, nullable=False, default=0)
    platform_fee_snapshot = Column(Text, nullable=True)
    status = Column(String(24), nullable=False, default="pending")
    payment_status = Column(String(32), nullable=False, default="pending")
    extras = Column(Text, nullable=True)
    km_start = Column(Integer, nullable=True)
    km_end = Column(Integer, nullable=True)
    company = relationship("RentalCompany")
    vehicle = relationship("RentalVehicle")
    plan = relationship("RentalPlan")
    checkin = relationship("RentalCheckin", back_populates="reservation", uselist=False)
    checkout = relationship("RentalCheckout", back_populates="reservation", uselist=False)
