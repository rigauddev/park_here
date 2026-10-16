from sqlalchemy import Boolean, Column, Float, ForeignKey, String, Text

from app.db.base import BaseModel


class ParkingConvenienceProduct(BaseModel):
    """Products sold by a parking unit, independent from reservation extras."""

    __tablename__ = "parking_convenience_products"

    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=False)
    category = Column(String(80), nullable=False)
    subcategory = Column(String(80), nullable=True)
    name = Column(String(160), nullable=False)
    description = Column(Text, nullable=True)
    price = Column(Float, nullable=False, default=0)
    is_active = Column(Boolean, nullable=False, default=True)
