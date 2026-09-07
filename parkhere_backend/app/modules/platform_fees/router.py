from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.platform_fees.models import PlatformFee
from app.modules.users.models.user_model import User
from app.modules.users.models.user_model_role_enum import UserRoleEnum

router = APIRouter(prefix='/admin/platform-fees', tags=['Platform fees'])


class PlatformFeeRequest(BaseModel):
    service_type: str
    fee_mode: str = 'hybrid'
    fixed_amount: float = Field(default=0, ge=0)
    percentage: float = Field(default=0, ge=0, le=100)
    min_fee: float = Field(default=0, ge=0)
    max_fee: float | None = Field(default=None, ge=0)
    is_active: bool = True


def _ensure_admin(user: User) -> None:
    if user.role != UserRoleEnum.SUPER_ADMIN:
        raise HTTPException(status_code=403, detail='System administrator required')


@router.get('')
async def list_platform_fees(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _ensure_admin(current_user)
    rows = (await db.scalars(select(PlatformFee).order_by(PlatformFee.service_type))).all()
    return [_fee_payload(row) for row in rows]


@router.put('/{service_type}')
async def upsert_platform_fee(
    service_type: str,
    data: PlatformFeeRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _ensure_admin(current_user)
    row = await db.scalar(select(PlatformFee).where(PlatformFee.service_type == service_type))
    if row is None:
        row = PlatformFee(service_type=service_type)
        db.add(row)
    row.fee_mode = data.fee_mode
    row.fixed_amount = data.fixed_amount
    row.percentage = data.percentage
    row.min_fee = data.min_fee
    row.max_fee = data.max_fee
    row.is_active = data.is_active
    await db.commit()
    await db.refresh(row)
    return _fee_payload(row)


def _fee_payload(row: PlatformFee) -> dict:
    return {
        'service_type': row.service_type,
        'fee_mode': row.fee_mode,
        'fixed_amount': row.fixed_amount,
        'percentage': row.percentage,
        'min_fee': row.min_fee,
        'max_fee': row.max_fee,
        'is_active': row.is_active,
    }
