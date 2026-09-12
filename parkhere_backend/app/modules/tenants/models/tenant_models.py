from sqlalchemy import Column, String, Enum, DateTime, Integer
from sqlalchemy.sql import func
from app.db.base import BaseModel

from app.modules.tenants.models.tenant_model_plan_enum import PlanEnum
from app.modules.tenants.models.tenant_model_status_enum import TenantStatusEnum


class Tenant(BaseModel):
    __tablename__ = "tenants"

    name = Column(String(255), nullable=False)
    cnpj = Column(String(20), nullable=False, unique=True)
    email = Column(String(255), nullable=False)

    plan = Column(Enum(PlanEnum), default=PlanEnum.FREE)
    status = Column(Enum(TenantStatusEnum), default=TenantStatusEnum.TRIAL)
    operator_limit_override = Column(Integer, nullable=True)

    trial_ends_at = Column(DateTime(timezone=True), nullable=True)
