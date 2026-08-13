from sqlalchemy import Column, String, Boolean, Float, Enum, ForeignKey
from sqlalchemy.orm import relationship
from app.db.base import BaseModel
from app.modules.users.models.user_model_role_enum import UserRoleEnum


class User(BaseModel):
    __tablename__ = "users"

    tenant_id = Column(
        String(36),
        ForeignKey("tenants.id"),
        nullable=True  # customer pode ser null
    )

    name = Column(String(255), nullable=False)
    firt_name = Column(String(255), nullable=False)

    email = Column(String(255), nullable=False, unique=True)
    password_hash = Column(String(255), nullable=False)

    phone = Column(String(20), nullable=True)

    phone_verified = Column(Boolean, default=False)
    email_verified = Column(Boolean, default=False)

    role = Column(
        Enum(UserRoleEnum),
        default=UserRoleEnum.CUSTOMER
    )

    commission_percentage = Column(Float, nullable=True)

    is_active = Column(Boolean, default=True)

    tenant = relationship("Tenant")