from sqlalchemy import Boolean, Column, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import relationship

from app.db.base import BaseModel


class ParkingConvenienceProduct(BaseModel):
    """Products sold by a parking unit, independent from reservation extras."""

    __tablename__ = "parking_convenience_products"

    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=False)
    category_id = Column(String(36), ForeignKey("parking_convenience_categories.id"), nullable=True)
    category = Column(String(80), nullable=False)
    subcategory = Column(String(80), nullable=True)
    name = Column(String(160), nullable=False)
    description = Column(Text, nullable=True)
    price = Column(Float, nullable=False, default=0)
    barcode = Column(String(80), nullable=True, index=True)
    is_active = Column(Boolean, nullable=False, default=True)


class ParkingConvenienceCategory(BaseModel):
    """Tenant-owned reusable category and optional subcategory for products."""

    __tablename__ = "parking_convenience_categories"
    __table_args__ = (UniqueConstraint(
        "tenant_id", "name", "subcategory", name="uq_convenience_category_tenant_name_subcategory"
    ),)

    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False, index=True)
    name = Column(String(80), nullable=False)
    subcategory = Column(String(80), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)


class ParkingConvenienceSale(BaseModel):
    __tablename__ = "parking_convenience_sales"

    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False, index=True)
    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=False, index=True)
    operator_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    payment_method = Column(String(20), nullable=False, default="cash")
    total_amount = Column(Float, nullable=False, default=0)
    cash_received = Column(Float, nullable=True)
    change_amount = Column(Float, nullable=False, default=0)


class ParkingConvenienceSaleItem(BaseModel):
    __tablename__ = "parking_convenience_sale_items"

    sale_id = Column(String(36), ForeignKey("parking_convenience_sales.id"), nullable=False, index=True)
    product_id = Column(String(36), ForeignKey("parking_convenience_products.id"), nullable=False)
    quantity = Column(Integer, nullable=False, default=1)
    unit_price = Column(Float, nullable=False, default=0)
    total_price = Column(Float, nullable=False, default=0)
