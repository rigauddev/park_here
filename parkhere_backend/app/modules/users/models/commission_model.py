
from app.modules.users.models.user_model_role_enum import CommissionType
from sqlalchemy import Column, ForeignKey, Enum, Float
from uuid import UUID
from app.core.database import Base


class GuideCommission(Base):

    __tablename__ = "guide_commissions"

    id = Column(UUID, primary_key=True)

    user_id = Column(
        UUID,
        ForeignKey("users.id")
    )

    tenant_id = Column(
        UUID,
        ForeignKey("tenants.id")
    )

    commission_type = Column(
        Enum(CommissionType)
    )

    value = Column(Float)