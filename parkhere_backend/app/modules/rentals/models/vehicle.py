from sqlalchemy import Column, String, Float, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from app.db.base import BaseModel

class Vehicle(BaseModel):
    __tablename__ = "vehicles"

    company_id = Column(String(36), ForeignKey("rental_companies.id"), nullable=False)
    model = Column(String(120), nullable=False)
    brand = Column(String(80), nullable=False)
    price_per_day = Column(Float, nullable=False)
    status = Column(String(20), nullable=False, default="available")
    # optional fields
    plate = Column(String(20), nullable=True)
    year = Column(Integer, nullable=True)

    company = relationship("RentalCompany", back_populates="vehicles")

