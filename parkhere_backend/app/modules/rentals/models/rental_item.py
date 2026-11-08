from sqlalchemy import Boolean, Column, ForeignKey, String, Text
from sqlalchemy.orm import relationship

from app.db.base import BaseModel


class RentalItem(BaseModel):
    __tablename__ = "rental_items"

    company_id = Column(String(36), ForeignKey("rental_companies.id"), nullable=False, index=True)
    name = Column(String(100), nullable=False)
    category = Column(String(40), nullable=False, default="accessory")
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)

    company = relationship("RentalCompany")
