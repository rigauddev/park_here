from sqlalchemy import Boolean, Column, Float, String

from app.db.base import BaseModel


class PlatformFee(BaseModel):
    __tablename__ = "platform_fees"

    service_type = Column(String(50), nullable=False, unique=True)
    fee_mode = Column(String(20), nullable=False, default="hybrid")
    fixed_amount = Column(Float, nullable=False, default=0)
    percentage = Column(Float, nullable=False, default=0)
    min_fee = Column(Float, nullable=False, default=0)
    max_fee = Column(Float, nullable=True)
    is_active = Column(Boolean, default=True)
