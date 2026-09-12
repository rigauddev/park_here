import json
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.platform_fees.models import (
    PlatformFee,
    PartnerPlatformFee,
    ParkingPlatformFee,
    PartnerFeatureEntitlement,
    EmailTemplate,
    AdminAuditLog,
)
from app.modules.platform_fees.feature_catalog import features_for_service_type
from app.modules.users.models.user_model_role_enum import UserRoleEnum
from app.modules.tenants.models.tenant_models import Tenant
from app.modules.tenants.models.tenant_model_status_enum import TenantStatusEnum
from app.modules.parkings.models import Parking, ParkingService
from app.modules.users.models.user_model import User
from app.modules.partners.operator_package_models import OperatorPackageRequest
from app.modules.partners.models import PartnerProfile
from app.modules.partners.guide_service_models import GuideService
from app.core.email_service import EmailService

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
    reason: str | None = Field(default=None, min_length=5, max_length=1000)


class OperatorCapacityRequest(BaseModel):
    operator_limit: int = Field(ge=0, le=10000)


class PartnerFeatureRequest(BaseModel):
    is_enabled: bool
    is_paid: bool = False
    price: float = Field(default=0, ge=0)
    billing_period: str = 'monthly'
    notes: str | None = Field(default=None, max_length=500)


class EmailTemplateRequest(BaseModel):
    display_name: str = Field(min_length=2, max_length=120)
    subject: str = Field(min_length=3, max_length=255)
    header_html: str
    body_html: str
    footer_html: str
    is_active: bool = True


class ParkingUnitUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=255)
    address: str | None = Field(default=None, min_length=3, max_length=255)
    city: str | None = Field(default=None, min_length=2, max_length=120)
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)


def _ensure_admin(user: User) -> None:
    if user.role != UserRoleEnum.SUPER_ADMIN:
        raise HTTPException(status_code=403, detail='System administrator required')


def _audit(db: AsyncSession, actor: User, action: str, target_type: str,
           target_id: str, tenant_id: str | None, details: dict):
    db.add(AdminAuditLog(
        actor_id=actor.id,
        tenant_id=tenant_id,
        action=action,
        target_type=target_type,
        target_id=target_id,
        details=json.dumps(details, ensure_ascii=False, default=str),
    ))


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
        calculated_operator_limit = max(1, sum(1 for parking in parkings if parking.is_active)) * 2
        allowed_operators = tenant.operator_limit_override if tenant.operator_limit_override is not None else calculated_operator_limit
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
            'parkings': [{'id': parking.id, 'name': parking.name, 'address': parking.address,
                'city': parking.city, 'lat': parking.lat, 'lng': parking.lng,
                'is_active': parking.is_active, 'service_type': 'parking'} for parking in parkings],
            'services': service_rows,
            'services_count': parking_service_count + guide_service_count,
            'operator_count': operator_count,
            'operator_limit': int(allowed_operators) + int(extra),
            'base_operator_limit': int(allowed_operators),
            'approved_extra_operators': int(extra),
            'operator_limit_override': tenant.operator_limit_override,
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
    _audit(db, current_user, 'partner.fee.updated', 'partner_fee', item.id or tenant_id, tenant_id, data.model_dump())
    await db.commit()
    return {'tenant_id': tenant_id, 'service_type': service_type, 'source': 'partner', **_fee_payload(item)}


@router.get('/partners/{tenant_id}/units/{parking_id}')
async def get_partner_unit(tenant_id: str, parking_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    unit = await db.scalar(select(Parking).where(Parking.id == parking_id, Parking.tenant_id == tenant_id))
    if unit is None:
        raise HTTPException(status_code=404, detail='Unidade não encontrada para este parceiro')
    return _unit_payload(unit)


@router.patch('/partners/{tenant_id}/units/{parking_id}')
async def update_partner_unit(tenant_id: str, parking_id: str, data: ParkingUnitUpdateRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    unit = await db.scalar(select(Parking).where(Parking.id == parking_id, Parking.tenant_id == tenant_id))
    if unit is None:
        raise HTTPException(status_code=404, detail='Unidade não encontrada para este parceiro')
    changes = data.model_dump(exclude_unset=True, exclude_none=True)
    if not changes:
        raise HTTPException(status_code=422, detail='Informe ao menos um campo da unidade')
    before = {key: getattr(unit, key) for key in changes}
    for key, value in changes.items():
        setattr(unit, key, value)
    _audit(db, current_user, 'partner.unit.updated', 'parking_unit', unit.id, tenant_id, {'before': before, 'after': changes})
    await db.commit()
    await db.refresh(unit)
    return _unit_payload(unit)


@router.get('/partners/{tenant_id}/units/{parking_id}/fees')
async def get_partner_unit_fees(tenant_id: str, parking_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    unit = await db.scalar(select(Parking).where(Parking.id == parking_id, Parking.tenant_id == tenant_id))
    if unit is None:
        raise HTTPException(status_code=404, detail='Unidade não encontrada para este parceiro')
    global_rows = (await db.scalars(select(PlatformFee).order_by(PlatformFee.service_type))).all()
    partner_rows = (await db.scalars(select(PartnerPlatformFee).where(PartnerPlatformFee.tenant_id == tenant_id))).all()
    unit_rows = (await db.scalars(select(ParkingPlatformFee).where(ParkingPlatformFee.parking_id == parking_id))).all()
    partner_by_type = {fee.service_type: fee for fee in partner_rows}
    unit_by_type = {fee.service_type: fee for fee in unit_rows}
    rows = []
    seen = set()
    for global_fee in global_rows:
        service_type = global_fee.service_type
        effective = unit_by_type.get(service_type) or partner_by_type.get(service_type) or global_fee
        source = 'unit' if service_type in unit_by_type else 'partner' if service_type in partner_by_type else 'global'
        rows.append({**_fee_payload(effective), 'source': source, 'tenant_id': tenant_id, 'parking_id': parking_id})
        seen.add(service_type)
    for fee in unit_rows:
        if fee.service_type not in seen:
            rows.append({**_fee_payload(fee), 'source': 'unit', 'tenant_id': tenant_id, 'parking_id': parking_id})
            seen.add(fee.service_type)
    for fee in partner_rows:
        if fee.service_type not in seen:
            rows.append({**_fee_payload(fee), 'source': 'partner', 'tenant_id': tenant_id, 'parking_id': parking_id})
    return rows


@router.put('/partners/{tenant_id}/units/{parking_id}/fees/{service_type}')
async def set_partner_unit_fee(tenant_id: str, parking_id: str, service_type: str, data: PlatformFeeRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    unit = await db.scalar(select(Parking).where(Parking.id == parking_id, Parking.tenant_id == tenant_id))
    if unit is None:
        raise HTTPException(status_code=404, detail='Unidade não encontrada para este parceiro')
    item = await db.scalar(select(ParkingPlatformFee).where(
        ParkingPlatformFee.parking_id == parking_id,
        ParkingPlatformFee.service_type == service_type,
    ))
    if item is None:
        item = ParkingPlatformFee(tenant_id=tenant_id, parking_id=parking_id, service_type=service_type)
        db.add(item)
    before = _fee_payload(item) if item.id else None
    item.fee_mode = data.fee_mode
    item.fixed_amount = data.fixed_amount
    item.percentage = data.percentage
    item.min_fee = data.min_fee
    item.max_fee = data.max_fee
    item.is_active = data.is_active
    _audit(db, current_user, 'partner.unit_fee.updated', 'parking_unit_fee', item.id or parking_id, tenant_id,
           {'service_type': service_type, 'before': before, 'after': data.model_dump()})
    await db.commit()
    await db.refresh(item)
    return {'source': 'unit', 'tenant_id': tenant_id, 'parking_id': parking_id, **_fee_payload(item)}


def _unit_payload(unit: Parking) -> dict:
    return {
        'id': unit.id, 'tenant_id': unit.tenant_id, 'service_type': 'parking',
        'name': unit.name, 'address': unit.address, 'city': unit.city,
        'lat': unit.lat, 'lng': unit.lng, 'is_active': unit.is_active,
        'total_spots': unit.total_spots, 'available_spots': unit.available_spots,
    }


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
    if not data.is_active and not (data.reason and data.reason.strip()):
        raise HTTPException(status_code=422, detail='Informe o motivo da desativação')
    user.is_active = data.is_active
    user.deactivation_reason = None if data.is_active else data.reason.strip()
    _audit(db, current_user, 'user.status.updated', 'user', user.id, user.tenant_id,
           {'is_active': user.is_active, 'reason': user.deactivation_reason})
    await db.commit()
    if not data.is_active:
        await EmailService.send_template(
            db, user.email, 'user_deactivation', 'pt_BR',
            {'name': user.name, 'reason': user.deactivation_reason or ''},
        )
    return {'id': user.id, 'is_active': user.is_active}


@router.patch('/partners/{tenant_id}/status')
async def set_partner_status(tenant_id: str, data: UserActiveRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    tenant = await db.get(Tenant, tenant_id)
    if tenant is None:
        raise HTTPException(status_code=404, detail='Parceiro não encontrado')
    if not data.is_active and not (data.reason and data.reason.strip()):
        raise HTTPException(status_code=422, detail='Informe o motivo da desativação')
    profile = await db.scalar(select(PartnerProfile).where(PartnerProfile.tenant_id == tenant_id))
    previous = tenant.status.value
    tenant.status = TenantStatusEnum.ACTIVE if data.is_active else TenantStatusEnum.SUSPENDED
    if profile is not None:
        profile.approval_status = 'approved' if data.is_active else 'suspended'
    _audit(db, current_user, 'partner.status.updated', 'partner', tenant.id, tenant.id,
           {'previous': previous, 'is_active': data.is_active, 'reason': data.reason})
    await db.commit()
    if not data.is_active:
        recipients = (await db.scalars(select(User).where(
            User.tenant_id == tenant_id, User.is_active.is_(True)
        ))).all()
        for recipient in recipients:
            await EmailService.send_template(
                db, recipient.email, 'partner_deactivation', 'pt_BR',
                {'name': recipient.name, 'company': tenant.name, 'reason': data.reason or ''},
            )
    return {'tenant_id': tenant.id, 'is_active': data.is_active, 'status': tenant.status.value}


@router.put('/partners/{tenant_id}/operator-capacity')
async def set_partner_operator_capacity(tenant_id: str, data: OperatorCapacityRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    tenant = await db.get(Tenant, tenant_id)
    if tenant is None:
        raise HTTPException(status_code=404, detail='Parceiro não encontrado')
    previous = tenant.operator_limit_override
    tenant.operator_limit_override = data.operator_limit
    _audit(db, current_user, 'partner.operator_capacity.updated', 'partner', tenant.id, tenant.id,
           {'previous_override': previous, 'operator_limit_override': data.operator_limit})
    await db.commit()
    return {'tenant_id': tenant.id, 'operator_limit': data.operator_limit, 'source': 'admin_override'}


@router.get('/partners/{tenant_id}/features')
async def get_partner_features(tenant_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    if await db.get(Tenant, tenant_id) is None:
        raise HTTPException(status_code=404, detail='Parceiro não encontrado')
    profile = await db.scalar(select(PartnerProfile).where(PartnerProfile.tenant_id == tenant_id))
    catalog = features_for_service_type(profile.service_type if profile else None)
    rows = (await db.scalars(select(PartnerFeatureEntitlement).where(
        PartnerFeatureEntitlement.tenant_id == tenant_id
    ))).all()
    by_key = {row.feature_key: row for row in rows}
    return [{
        **feature,
        'service_types': list(feature['service_types']),
        'tenant_id': tenant_id,
        'is_enabled': by_key[feature['key']].is_enabled if feature['key'] in by_key else False,
        'is_paid': by_key[feature['key']].is_paid if feature['key'] in by_key else False,
        'price': by_key[feature['key']].price if feature['key'] in by_key else 0,
        'billing_period': by_key[feature['key']].billing_period if feature['key'] in by_key else 'monthly',
        'notes': by_key[feature['key']].notes if feature['key'] in by_key else None,
    } for feature in catalog]


@router.put('/partners/{tenant_id}/features/{feature_key}')
async def set_partner_feature(tenant_id: str, feature_key: str, data: PartnerFeatureRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    if await db.get(Tenant, tenant_id) is None:
        raise HTTPException(status_code=404, detail='Parceiro não encontrado')
    profile = await db.scalar(select(PartnerProfile).where(PartnerProfile.tenant_id == tenant_id))
    catalog = features_for_service_type(profile.service_type if profile else None)
    if feature_key not in {feature['key'] for feature in catalog}:
        raise HTTPException(status_code=404, detail='Funcionalidade não cadastrada')
    if data.is_paid and data.price <= 0:
        raise HTTPException(status_code=422, detail='Informe um preço maior que zero para uma funcionalidade paga')
    if data.billing_period not in {'monthly', 'annual', 'one_time'}:
        raise HTTPException(status_code=422, detail='Periodicidade inválida')
    item = await db.scalar(select(PartnerFeatureEntitlement).where(
        PartnerFeatureEntitlement.tenant_id == tenant_id,
        PartnerFeatureEntitlement.feature_key == feature_key,
    ))
    if item is None:
        item = PartnerFeatureEntitlement(tenant_id=tenant_id, feature_key=feature_key)
        db.add(item)
    before = {'is_enabled': item.is_enabled, 'is_paid': item.is_paid, 'price': item.price} if item.id else None
    item.is_enabled = data.is_enabled
    item.is_paid = data.is_paid
    item.price = data.price
    item.billing_period = data.billing_period
    item.notes = data.notes
    _audit(db, current_user, 'partner.feature.updated', 'partner_feature', item.id or tenant_id,
           tenant_id, {'feature_key': feature_key, 'before': before, 'after': data.model_dump()})
    await db.commit()
    await db.refresh(item)
    return {'tenant_id': tenant_id, 'feature_key': feature_key, 'is_enabled': item.is_enabled,
            'is_paid': item.is_paid, 'price': item.price, 'billing_period': item.billing_period,
            'notes': item.notes}


@router.get('/email-templates')
async def list_email_templates(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    rows = (await db.scalars(select(EmailTemplate).order_by(EmailTemplate.template_key, EmailTemplate.locale))).all()
    return [_email_template_payload(row) for row in rows]


@router.put('/email-templates/{template_key}/{locale}')
async def update_email_template(template_key: str, locale: str, data: EmailTemplateRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    if locale not in {'pt_BR', 'en'}:
        raise HTTPException(status_code=422, detail='Idioma não suportado')
    row = await db.scalar(select(EmailTemplate).where(
        EmailTemplate.template_key == template_key, EmailTemplate.locale == locale
    ))
    if row is None:
        raise HTTPException(status_code=404, detail='Modelo de e-mail não encontrado')
    before = _email_template_payload(row)
    for key, value in data.model_dump().items():
        setattr(row, key, value)
    _audit(db, current_user, 'email_template.updated', 'email_template', row.id, None,
           {'before': before, 'after': data.model_dump()})
    await db.commit()
    await db.refresh(row)
    return _email_template_payload(row)


@router.get('/audit-logs')
async def list_admin_audit_logs(limit: int = 100, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    _ensure_admin(current_user)
    rows = (await db.scalars(select(AdminAuditLog).order_by(AdminAuditLog.created_at.desc()).limit(max(1, min(limit, 500))))).all()
    return [{
        'id': row.id, 'actor_id': row.actor_id, 'tenant_id': row.tenant_id,
        'action': row.action, 'target_type': row.target_type, 'target_id': row.target_id,
        'details': json.loads(row.details) if row.details else {},
        'created_at': row.created_at.isoformat() + 'Z',
    } for row in rows]


def _email_template_payload(row: EmailTemplate) -> dict:
    return {
        'id': row.id, 'template_key': row.template_key, 'locale': row.locale,
        'display_name': row.display_name, 'subject': row.subject,
        'header_html': row.header_html, 'body_html': row.body_html,
        'footer_html': row.footer_html, 'is_active': row.is_active,
    }


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
    previous = service.is_active
    service.is_active = data.is_active
    _audit(db, current_user, 'partner.service.status.updated', 'partner_service',
           service.id, tenant_id, {'service_type': service_type, 'before': previous,
                                   'after': data.is_active})
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
    before = _fee_payload(row) if row is not None else None
    if row is None:
        row = PlatformFee(service_type=service_type)
        db.add(row)
    row.fee_mode = data.fee_mode
    row.fixed_amount = data.fixed_amount
    row.percentage = data.percentage
    row.min_fee = data.min_fee
    row.max_fee = data.max_fee
    row.is_active = data.is_active
    _audit(db, current_user, 'platform_fee.updated', 'platform_fee', service_type,
           None, {'before': before, 'after': data.model_dump()})
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
    previous = row.status
    row.status = 'approved' if decision == 'approve' else 'rejected'
    row.reviewed_by = current_user.id
    _audit(db, current_user, 'operator_package.reviewed', 'operator_package',
           row.id, row.tenant_id, {'before': previous, 'after': row.status})
    await db.commit()
    return {'id': row.id, 'status': row.status}
