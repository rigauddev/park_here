from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.platform_fees.models import PlatformFee
from app.modules.users.models.user_model_role_enum import UserRoleEnum
from app.modules.tenants.models.tenant_models import Tenant
from app.modules.parkings.models import Parking
from app.modules.users.models.user_model import User
from app.modules.partners.operator_package_models import OperatorPackageRequest
from app.modules.partners.models import PartnerProfile

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


@router.get('/overview')
async def admin_overview(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _ensure_admin(current_user)
    tenants = (await db.scalars(select(Tenant))).all()
    parkings = (await db.scalars(select(Parking))).all()
    users = (await db.scalars(select(User))).all()
    profiles = (await db.scalars(select(PartnerProfile))).all()
    city_rows = {}
    for parking in parkings:
        city = (parking.city or '').strip() or 'Não informado'
        item = city_rows.setdefault(city, {'city': city, 'parkings': 0, 'active_parkings': 0})
        item['parkings'] += 1
        item['active_parkings'] += int(bool(parking.is_active))
    return {
        'companies': len(tenants),
        'parkings': len(parkings),
        'active_parkings': sum(1 for item in parkings if item.is_active),
        'users': len(users),
        'customers': sum(1 for user in users if user.role == UserRoleEnum.CUSTOMER),
        'partners': sum(1 for user in users if user.role != UserRoleEnum.CUSTOMER and user.role != UserRoleEnum.SUPER_ADMIN),
        'partner_categories': {category: sum(1 for profile in profiles if profile.service_type == category) for category in ('parking', 'tour_guide', 'car_wash', 'hotel', 'restaurant', 'tourism_company', 'transport')},
        'cities': list(city_rows.values()),
        'plans': ['free', 'pro'],
        'plan_rules': {
            'free': {'parkings': 1, 'operators': 2, 'financial_reports': False},
            'pro': {'parkings': 'custom', 'operators': 'custom', 'financial_reports': True},
        },
    }


@router.get('/partners')
async def list_admin_partners(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Lista empresas parceiras com seus recursos para a gestão do sistema."""
    _ensure_admin(current_user)
    profiles = (await db.scalars(select(PartnerProfile))).all()
    result = []
    for profile in profiles:
        users = (await db.scalars(select(User).where(User.tenant_id == profile.tenant_id))).all()
        parkings = (await db.scalars(select(Parking).where(Parking.tenant_id == profile.tenant_id))).all()
        result.append({
            'tenant_id': profile.tenant_id,
            'company_name': profile.company_name,
            'service_type': profile.service_type,
            'approval_status': profile.approval_status,
            'users': [{'id': user.id, 'name': user.name, 'email': user.email, 'role': user.role.value, 'is_active': user.is_active} for user in users],
            'parkings': [{'id': parking.id, 'name': parking.name, 'city': parking.city, 'is_active': parking.is_active} for parking in parkings],
        })
    return result


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


@router.get('/operator-packages/requests')
async def list_operator_package_requests(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    rows = (await db.scalars(select(OperatorPackageRequest).order_by(OperatorPackageRequest.created_at.desc()))).all()
    return [{
        'id': row.id, 'tenant_id': row.tenant_id, 'quantity': row.quantity,
        'package_type': row.package_type, 'amount': row.amount,
        'status': row.status, 'has_receipt': bool(row.receipt_path),
        'created_at': row.created_at.isoformat() + 'Z',
    } for row in rows]


@router.post('/operator-packages/requests/{request_id}/{decision}')
async def review_operator_package_request(request_id: str, decision: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    if decision not in {'approve', 'reject'}:
        raise HTTPException(status_code=422, detail='Decision must be approve or reject')
    row = await db.scalar(select(OperatorPackageRequest).where(OperatorPackageRequest.id == request_id))
    if row is None:
        raise HTTPException(status_code=404, detail='Solicitação não encontrada')
    row.status = 'approved' if decision == 'approve' else 'rejected'
    row.reviewed_by = current_user.id
    await db.commit()
    return {'id': row.id, 'status': row.status}
