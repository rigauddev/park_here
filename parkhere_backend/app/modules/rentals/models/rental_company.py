from sqlalchemy import Column, String, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.db.base import BaseModel

class RentalCompany(BaseModel):
    __tablename__ = "rental_companies"

    name = Column(String(120), nullable=False)
    address = Column(String(200), nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    cnpj = Column(String(20), nullable=True)  # optional per branch
    is_active = Column(Boolean, default=True, nullable=False)

    vehicles = relationship("Vehicle", back_populates="company")

