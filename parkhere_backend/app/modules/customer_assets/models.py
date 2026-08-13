from sqlalchemy import Boolean, Column, ForeignKey, String

from app.db.base import BaseModel


class DriverDocument(BaseModel):
    __tablename__ = "driver_documents"

    user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    document_type = Column(String(20), nullable=False)
    document_number = Column(String(50), nullable=False)
    file_url = Column(String(255), nullable=True)
    is_verified = Column(Boolean, default=False)


class Vehicle(BaseModel):
    __tablename__ = "vehicles"

    user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    nickname = Column(String(80), nullable=False)
    plate = Column(String(20), nullable=False)
    brand = Column(String(80), nullable=False)
    model = Column(String(80), nullable=False)
    color = Column(String(40), nullable=False)
    vehicle_document = Column(String(80), nullable=False)
    ownership_type = Column(String(20), nullable=False)
    is_active = Column(Boolean, default=False)


class WalletPaymentMethod(BaseModel):
    __tablename__ = "wallet_payment_methods"

    user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    method_type = Column(String(20), nullable=False)
    label = Column(String(120), nullable=False)
    last_four = Column(String(4), nullable=True)
    pix_key = Column(String(120), nullable=True)
    is_active = Column(Boolean, default=False)
