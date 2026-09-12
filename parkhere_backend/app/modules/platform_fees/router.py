from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.platform_fees.models import PlatformFee, PartnerPlatformFee
from app.modules.users.models.user_model_role_enum import UserRoleEnum
from app.modules.tenants.models.tenant_models import Tenant
from app.modules.parkings.models import Parking, ParkingService
from app.modules.users.models.user_model import User
from app.modules.partners.operator_package_models import OperatorPackageRequest
from app.modules.partners.models import PartnerProfile
from app.modules.partners.guide_service_models import GuideService

router = APIRouter(prefix='/admin/platform-fees', tags=['Platform fees'])


class PlatformFeeRequest(BaseModel):
    service_type: str
    fee_mode: str = 'hybrid'
    fixed_amount: float = Field(default=0, ge=0)
    percentage: float = Field(default=0, ge=0, le=100)
    min_fee: float = Field(default=0, ge=0)
    max_fee: float | None = Field(default=None, ge=0)
    is_active: bool = True


class UserActiveRequest(BaseModel):
    is_active: bool


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
        'partners': len(profiles),
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
    tenants = (await db.scalars(select(Tenant).order_by(Tenant.created_at.desc()))).all()
    profiles = (await db.scalars(select(PartnerProfile))).all()
    profile_by_tenant = {profile.tenant_id: profile for profile in profiles}
    result = []
    for tenant in tenants:
        profile = profile_by_tenant.get(tenant.id)
        users = (await db.scalars(select(User).where(User.tenant_id == tenant.id).order_by(User.created_at))).all()
        parkings = (await db.scalars(select(Parking).where(Parking.tenant_id == tenant.id).order_by(Parking.created_at))).all()
        operator_count = sum(1 for user in users if user.role == UserRoleEnum.OPERATOR)
        allowed_operators = max(1, sum(1 for parking in parkings if parking.is_active)) * 2
        extra = await db.scalar(select(func.coalesce(func.sum(OperatorPackageRequest.quantity), 0)).where(OperatorPackageRequest.tenant_id == tenant.id, OperatorPackageRequest.status == 'approved')) or 0
        parking_service_count = await db.scalar(select(func.count(ParkingService.id)).join(Parking, Parking.id == ParkingService.parking_id).where(Parking.tenant_id == tenant.id, ParkingService.is_active.is_(True))) or 0
        parking_services = (await db.execute(
            select(ParkingService, Parking.name)
            .join(Parking, Parking.id == ParkingService.parking_id)
            .where(Parking.tenant_id == tenant.id)
            .order_by(Parking.name, ParkingService.name)
        )).all()
        guide_ids = [user.id for user in users if user.role == UserRoleEnum.TOUR_GUIDE]
        guide_service_count = 0
        guide_services = []
        if guide_ids:
            guide_service_count = await db.scalar(select(func.count(GuideService.id)).where(GuideService.guide_user_id.in_(guide_ids), GuideService.is_active.is_(True))) or 0
            guide_services = (await db.scalars(
                select(GuideService).where(GuideService.guide_user_id.in_(guide_ids)).order_by(GuideService.name)
            )).all()
        service_rows = [
            {'id': service.id, 'service_type': 'parking', 'name': service.name,
             'code': service.code, 'price': service.price, 'is_active': service.is_active,
             'unit_name': parking_name}
            for service, parking_name in parking_services
        ] + [
            {'id': service.id, 'service_type': 'tour_guide', 'name': service.name,
             'code': None, 'price': service.price, 'is_active': service.is_active,
             'unit_name': None}
            for service in guide_services
        ]
        result.append({
            'tenant_id': tenant.id,
            'company_name': profile.company_name if profile else tenant.name,
            'tenant_name': tenant.name,
            'tenant_status': tenant.status.value,
            'service_type': profile.service_type if profile else 'other',
            'approval_status': profile.approval_status if profile else 'profile_missing',
            'users': [{'id': user.id, 'name': user.name, 'email': user.email, 'role': user.role.value, 'is_active': user.is_active} for user in users],
            'parkings': [{'id': parking.id, 'name': parking.name, 'city': parking.city, 'is_active': parking.is_active} for parking in parkings],
            'services': service_rows,
            'services_count': parking_service_count + guide_service_count,
            'operator_count': operator_count,
            'operator_limit': allowed_operators + int(extra),
            'global_service_fee_count': await db.scalar(select(func.count(PlatformFee.id)).where(PlatformFee.is_active.is_(True))) or 0,
        })
    return result


@router.get('/partners/{tenant_id}/fees')
async def list_partner_fee_overrides(tenant_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    if await db.get(Tenant, tenant_id) is None:
        raise HTTPException(status_code=404, detail='Parceiro não encontrado')
    globals_ = (await db.scalars(select(PlatformFee).order_by(PlatformFee.service_type))).all()
    overrides = (await db.scalars(select(PartnerPlatformFee).where(PartnerPlatformFee.tenant_id == tenant_id))).all()
    override_by_type = {item.service_type: item for item in overrides}
    rows = [{**_fee_payload(global_fee), 'source': 'partner' if global_fee.service_type in override_by_type else 'global', 'tenant_id': tenant_id, **({
        'fee_mode': override_by_type[global_fee.service_type].fee_mode,
        'fixed_amount': override_by_type[global_fee.service_type].fixed_amount,
        'percentage': override_by_type[global_fee.service_type].percentage,
        'min_fee': override_by_type[global_fee.service_type].min_fee,
        'max_fee': override_by_type[global_fee.service_type].max_fee,
        'is_active': override_by_type[global_fee.service_type].is_active,
    } if global_fee.service_type in override_by_type else {})} for global_fee in globals_]
    global_types = {item.service_type for item in globals_}
    rows.extend({**_fee_payload(item), 'source': 'partner', 'tenant_id': tenant_id} for item in overrides if item.service_type not in global_types)
    return rows


@router.put('/partners/{tenant_id}/fees/{service_type}')
async def set_partner_fee_override(tenant_id: str, service_type: str, data: PlatformFeeRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    if await db.get(Tenant, tenant_id) is None:
        raise HTTPException(status_code=404, detail='Parceiro não encontrado')
    item = await db.scalar(select(PartnerPlatformFee).where(PartnerPlatformFee.tenant_id == tenant_id, PartnerPlatformFee.service_type == service_type))
    if item is None:
        item = PartnerPlatformFee(tenant_id=tenant_id, service_type=service_type)
        db.add(item)
    item.fee_mode = data.fee_mode
    item.fixed_amount = data.fixed_amount
    item.percentage = data.percentage
    item.min_fee = data.min_fee
    item.max_fee = data.max_fee
    item.is_active = data.is_active
    await db.commit()
    return {'tenant_id': tenant_id, 'service_type': service_type, 'source': 'partner', **_fee_payload(item)}


@router.get('/customers')
async def list_admin_customers(query: str | None = None, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    statement = select(User).where(User.role == UserRoleEnum.CUSTOMER)
    if query:
        needle = f"%{query.strip()}%"
        statement = statement.where((User.name.ilike(needle)) | (User.email.ilike(needle)) | (User.phone.ilike(needle)))
    users = (await db.scalars(statement.order_by(User.created_at.desc()).limit(500))).all()
    return [{'id': user.id, 'name': user.name, 'email': user.email, 'phone': user.phone, 'is_active': user.is_active, 'created_at': user.created_at.isoformat() + 'Z'} for user in users]


@router.patch('/users/{user_id}/status')
async def set_admin_user_status(user_id: str, data: UserActiveRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    user = await db.get(User, user_id)
    if user is None or user.role == UserRoleEnum.SUPER_ADMIN:
        raise HTTPException(status_code=404, detail='Usuário não encontrado')
    user.is_active = data.is_active
    await db.commit()
    return {'id': user.id, 'is_active': user.is_active}


@router.patch('/partners/{tenant_id}/services/{service_type}/{service_id}/status')
async def set_partner_service_status(
    tenant_id: str,
    service_type: str,
    service_id: str,
    data: UserActiveRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _ensure_admin(current_user)
    if service_type == 'parking':
        service = await db.scalar(
            select(ParkingService)
            .join(Parking, Parking.id == ParkingService.parking_id)
            .where(Parking.tenant_id == tenant_id, ParkingService.id == service_id)
        )
    elif service_type == 'tour_guide':
        service = await db.scalar(
            select(GuideService)
            .join(User, User.id == GuideService.guide_user_id)
            .where(User.tenant_id == tenant_id, GuideService.id == service_id)
        )
    else:
        raise HTTPException(status_code=422, detail='Tipo de serviço inválido')
    if service is None:
        raise HTTPException(status_code=404, detail='Serviço não encontrado')
    service.is_active = data.is_active
    await db.commit()
    return {'id': service.id, 'service_type': service_type, 'is_active': service.is_active}


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
