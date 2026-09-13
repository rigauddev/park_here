import json
import re
from uuid import uuid4
from datetime import datetime, timedelta
from math import ceil
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from pathlib import Path
from pydantic import BaseModel, field_validator
from sqlalchemy import delete, select
from sqlalchemy import func
from sqlalchemy.orm import aliased
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.core.database import get_db
from app.core.security import hash_password
from app.modules.auth.auth_service import AuthService
from app.modules.auth.schemas import PartnerSignupRequest
from app.modules.customer_assets.models import Vehicle
from app.modules.parkings.models import Parking, ParkingService
from app.modules.parkings.schemas import (
    ParkingManagementRequest,
    ParkingManagementResponse,
)
from app.modules.parkings.service import ParkingManagementService
from app.modules.partners.models import PartnerProfile
from app.modules.partners.guide_models import GuideParkingLink, GuideReview
from app.modules.partners.guide_service_models import GuideService
from app.modules.partners.operator_assignment_models import OperatorParkingAssignment, OperatorWorkShift
from app.modules.partners.work_schedule_models import OperatorWorkProfile, OperatorScheduleHistory
from app.modules.partners.operator_package_models import OperatorPackageRequest
from app.modules.platform_fees.models import PartnerFeatureEntitlement, PartnerFeatureRequest
from app.modules.platform_fees.feature_catalog import feature_by_key, features_for_service_type
from app.modules.tenants.models.tenant_models import Tenant
from app.modules.partners.document_models import PartnerDocument
from app.modules.payments.models import PartnerPaymentAccount, PartnerFeeDebt, PartnerFeeSettlement, PaymentTransaction
from app.modules.reservations.service import (
    calculate_checkout_excess,
    expire_parking_reservations,
    physical_spot_type,
)
from app.modules.reservations.models import Reservation
from app.modules.users.models.user_model import User
from app.modules.users.models.user_model_role_enum import UserRoleEnum

router = APIRouter(prefix="/partners", tags=["Partners"])

PARTNER_DOCUMENT_TYPES = {'alvara', 'rg', 'cnh'}

FREE_OPERATOR_LIMIT = 2
OPERATOR_PERMISSION_LABELS = {
    "reservations.view": "Ver reservas recebidas",
    "parking_map.view": "Ver patio de vagas",
    "reservations.create": "Criar reserva operacional",
    "reservations.cancel_own": "Cancelar reservas criadas pelo operador",
    "checkin.own": "Realizar check-in de reservas criadas pelo operador",
    "checkout.own": "Realizar checkout de reservas criadas pelo operador",
    "payments.receive": "Receber pagamento no local",
}
DEFAULT_OPERATOR_PERMISSIONS = list(OPERATOR_PERMISSION_LABELS.keys())
OWNER_PERMISSIONS = [
    "partner.company.manage",
    "partner.users.manage",
    "partner.pricing.manage",
    *DEFAULT_OPERATOR_PERMISSIONS,
]


class PartnerOperatorCreateRequest(BaseModel):
    name: str
    email: str
    phone: str | None = None
    cpf: str | None = None
    password: str
    accepted_terms: bool
    permissions: list[str] | None = None

    @field_validator("cpf")
    @classmethod
    def normalize_cpf(cls, value: str | None) -> str | None:
        if value is None or not value.strip():
            return None
        digits = re.sub(r"\D", "", value)
        if len(digits) != 11 or len(set(digits)) == 1:
            raise ValueError("CPF inválido")
        return digits

class OperatorPackageRequestCreate(BaseModel):
    quantity: int
    package_type: str = "individual"
    amount: float = 0

class OperatorParkingAssignmentRequest(BaseModel):
    parking_ids: list[str]

class OperatorShiftRequest(BaseModel):
    operator_id: str | None = None
    parking_id: str
    starts_at: datetime
    ends_at: datetime

class OperatorShiftUpdateRequest(BaseModel):
    operator_id: str | None
    starts_at: datetime
    ends_at: datetime

class OperatorWorkProfileRequest(BaseModel):
    operator_id: str
    parking_id: str
    daily_hours: float = 8
    lunch_minutes: int = 60
    days_off: list[int] = []
    work_modality: str = "8h"
    bank_hours: float = 0

class ShiftSuggestionRequest(BaseModel):
    parking_id: str
    operator_ids: list[str]
    starts_on: datetime
    ends_on: datetime
    daily_hours: float = 8
    opening_time: str | None = None
    closing_time: str | None = None
    work_regime: str | None = None


class PartnerOperatorResponse(BaseModel):
    id: str
    name: str
    email: str
    phone: str | None
    cpf: str | None = None
    role: str
    permissions: list[str]
    is_active: bool
    created_at: str


class GuideCommissionRequest(BaseModel):
    commission_type: str = 'percentage'
    commission_value: float = 0
    terms: dict[str, dict[str, str | float]] | None = None
    accepts_affiliates: bool | None = None


class GuideReviewRequest(BaseModel):
    rating: int
    comment: str | None = None


class GuideServiceRequest(BaseModel):
    name: str
    description: str | None = None
    price: float = 0
    duration_minutes: str | None = None
    is_active: bool = True
    schedule: dict[str, str] | None = None


class PartnerFeatureActivationRequest(BaseModel):
    feature_key: str
    quantity: int = 1
    billing_period: str
    payment_method: str
    notes: str | None = None


@router.post("/signup")
async def partner_signup(
    data: PartnerSignupRequest,
    db: AsyncSession = Depends(get_db),
):
    user = await AuthService.register_partner(db, data)

    profile = PartnerProfile(
        tenant_id=user.tenant_id,
        service_type=data.service_type,
        company_name=data.company_name,
        cnpj=data.document_number,
        document_type=data.document_type,
        document_number=data.document_number,
        registration_status="pending",
        responsible_name=data.responsible_name,
        has_insurance=data.has_insurance,
        insurance_provider=data.insurance_provider,
        instagram=data.instagram,
        website=data.website,
        social_links=data.social_links,
    )
    db.add(profile)
    await db.commit()

    return {
        "message": "Partner registered. Documents and inspection are required before publishing.",
        "tenant_id": user.tenant_id,
        "approval_status": profile.approval_status,
    }


@router.get("/me")
async def get_my_partner_profile(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _ensure_partner_user(current_user)

    profile_result = await db.execute(
        select(PartnerProfile).where(PartnerProfile.tenant_id == current_user.tenant_id)
    )
    profile = profile_result.scalar_one_or_none()

    payment_result = await db.execute(
        select(PartnerPaymentAccount)
        .where(PartnerPaymentAccount.tenant_id == current_user.tenant_id)
        .where(PartnerPaymentAccount.is_default.is_(True))
        .where(PartnerPaymentAccount.is_active.is_(True))
    )
    payment_account = payment_result.scalar_one_or_none()
    tenant = await db.get(Tenant, current_user.tenant_id)
    approved_extra = await db.scalar(select(func.coalesce(func.sum(OperatorPackageRequest.quantity), 0)).where(
        OperatorPackageRequest.tenant_id == current_user.tenant_id,
        OperatorPackageRequest.status == 'approved',
    )) or 0
    parking_count = await db.scalar(select(func.count(Parking.id)).where(
        Parking.tenant_id == current_user.tenant_id, Parking.is_active.is_(True)
    )) or 0
    total_parking_count = await db.scalar(select(func.count(Parking.id)).where(
        Parking.tenant_id == current_user.tenant_id
    )) or 0
    base_operator_limit = (
        tenant.operator_limit_override if tenant and tenant.operator_limit_override is not None
        else max(FREE_OPERATOR_LIMIT, int(parking_count or 1) * FREE_OPERATOR_LIMIT)
    )
    entitlements = (await db.scalars(select(PartnerFeatureEntitlement).where(
        PartnerFeatureEntitlement.tenant_id == current_user.tenant_id,
    ))).all()
    entitlements_by_key = {item.feature_key: item for item in entitlements}
    partner_features = {}
    for feature in features_for_service_type(profile.service_type if profile else None):
        item = entitlements_by_key.get(feature['key'])
        is_enabled = item.is_enabled if item else feature['default_is_enabled']
        if item and item.expires_at and item.expires_at.replace(tzinfo=None) <= datetime.utcnow():
            is_enabled = False
        partner_features[feature['key']] = {
            'name': feature['name'],
            'name_en': feature['name_en'],
            'description': feature['description'],
            'description_en': feature['description_en'],
            'is_enabled': is_enabled,
            'is_paid': item.is_paid if item else feature['default_is_paid'],
            'price': item.price if item else 0,
            'billing_period': item.billing_period if item else feature['default_billing_period'],
            'billing_prices': _feature_prices(item) if item else {},
            'expires_at': item.expires_at.isoformat() + 'Z' if item and item.expires_at else None,
            'notes': item.notes if item else None,
            'requestable': feature['requestable'],
            'quantity_based': feature.get('quantity_based', False),
        }

    unit_count = int(total_parking_count)
    service_count = 0
    if profile and profile.service_type == 'parking':
        service_count = int(await db.scalar(
            select(func.count(ParkingService.id))
            .join(Parking, Parking.id == ParkingService.parking_id)
            .where(Parking.tenant_id == current_user.tenant_id)
        ) or 0)
    elif profile and profile.service_type == 'tour_guide':
        service_count = int(await db.scalar(
            select(func.count(GuideService.id))
            .join(User, User.id == GuideService.guide_user_id)
            .where(User.tenant_id == current_user.tenant_id)
        ) or 0)
    approved_requests = (await db.scalars(select(PartnerFeatureRequest).where(
        PartnerFeatureRequest.tenant_id == current_user.tenant_id,
        PartnerFeatureRequest.status == 'approved',
        PartnerFeatureRequest.feature_key.in_(['additional_units', 'additional_services']),
    ))).all()
    approved_capacities = {
        key: max(
            [
                int(item.capacity_after or 0)
                for item in approved_requests
                if item.feature_key == key
            ]
            or [1]
        )
        for key in ('additional_units', 'additional_services')
    }
    unit_addon = partner_features.get('additional_units', {})
    service_addon = partner_features.get('additional_services', {})
    unit_limit = max(unit_count, approved_capacities['additional_units'])
    service_limit = max(service_count, approved_capacities['additional_services'])
    if unit_addon.get('is_paid') is False:
        unit_limit = 1000000
    elif unit_addon.get('is_enabled') is False:
        unit_limit = unit_count
    if service_addon.get('is_paid') is False:
        service_limit = 1000000
    elif service_addon.get('is_enabled') is False:
        service_limit = service_count

    return {
        "tenant_id": current_user.tenant_id,
        "role": current_user.role.value,
        "permissions": _user_permissions(current_user),
        "available_operator_permissions": OPERATOR_PERMISSION_LABELS,
        "user_email": current_user.email,
        "service_type": profile.service_type if profile else None,
        "document_type": profile.document_type if profile else None,
        "document_number": profile.document_number if profile else None,
        "company_name": profile.company_name if profile else None,
        "approval_status": profile.approval_status
        if profile
        else "missing_profile",
        "operator_limit": int(base_operator_limit) + int(approved_extra),
        "unit_count": unit_count,
        "unit_limit": unit_limit,
        "service_count": service_count,
        "service_limit": service_limit,
        "features": partner_features,
        "payment_account": {
            "provider": payment_account.provider,
            "status": payment_account.status,
            "account_label": payment_account.account_label,
        }
        if payment_account
        else None,
    }


@router.get('/feature-requests')
async def list_my_partner_feature_requests(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _ensure_partner_user(current_user)
    rows = (await db.scalars(
        select(PartnerFeatureRequest)
        .where(PartnerFeatureRequest.tenant_id == current_user.tenant_id)
        .order_by(PartnerFeatureRequest.created_at.desc())
    )).all()
    return [
        {
            'id': row.id,
            'feature_key': row.feature_key,
            'quantity': row.quantity,
            'total_price': row.total_price,
            'billing_period': row.billing_period,
            'payment_method': row.payment_method,
            'has_receipt': bool(row.receipt_path),
            'status': row.status,
            'created_at': row.created_at.isoformat() + 'Z',
        }
        for row in rows
    ]


@router.post('/feature-requests', status_code=201)
async def request_partner_feature(
    data: PartnerFeatureActivationRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _ensure_partner_user(current_user)
    if current_user.role == UserRoleEnum.OPERATOR:
        raise HTTPException(status_code=403, detail='Somente gestor pode solicitar funcionalidades')
    if data.quantity < 1 or data.quantity > 100:
        raise HTTPException(status_code=422, detail='Quantidade inválida')
    profile = await db.scalar(select(PartnerProfile).where(
        PartnerProfile.tenant_id == current_user.tenant_id
    ))
    feature = feature_by_key(profile.service_type if profile else None, data.feature_key)
    if feature is None or not feature['requestable']:
        raise HTTPException(status_code=404, detail='Funcionalidade não disponível para este parceiro')
    if not feature.get('quantity_based') and data.quantity != 1:
        raise HTTPException(status_code=422, detail='Esta solicitação não aceita quantidade')

    entitlement = await db.scalar(select(PartnerFeatureEntitlement).where(
        PartnerFeatureEntitlement.tenant_id == current_user.tenant_id,
        PartnerFeatureEntitlement.feature_key == data.feature_key,
    ))
    is_enabled = entitlement.is_enabled if entitlement else feature['default_is_enabled']
    is_paid = entitlement.is_paid if entitlement else feature['default_is_paid']
    unit_price = float(entitlement.price if entitlement else 0)
    billing_period = entitlement.billing_period if entitlement else feature['default_billing_period']
    if not is_paid:
        raise HTTPException(status_code=409, detail='Esta funcionalidade está configurada como gratuita; solicite ajuda ao suporte')
    if data.feature_key in {'additional_units', 'additional_services'} and not is_enabled:
        raise HTTPException(status_code=403, detail={
            'code': 'feature_locked', 'feature_key': data.feature_key,
            'message': 'A gestão do sistema desativou novas solicitações para este recurso.',
        })
    if data.feature_key not in {'additional_units', 'additional_services'} and is_enabled:
        raise HTTPException(status_code=409, detail='Esta funcionalidade já está liberada')

    if data.billing_period not in {'monthly', 'annual', 'one_time'}:
        raise HTTPException(status_code=422, detail='Escolha uma modalidade de cobrança válida')
    if data.payment_method not in {'credit_card', 'debit_card', 'pix'}:
        raise HTTPException(status_code=422, detail='Escolha Pix, débito ou crédito')
    prices = _feature_prices(entitlement) if entitlement else {}
    unit_price = float(prices.get(data.billing_period, unit_price if billing_period == data.billing_period else 0))
    if unit_price <= 0:
        raise HTTPException(status_code=409, detail='O valor desta modalidade ainda não foi configurado pela gestão do app')

    pending = await db.scalar(select(PartnerFeatureRequest).where(
        PartnerFeatureRequest.tenant_id == current_user.tenant_id,
        PartnerFeatureRequest.feature_key == data.feature_key,
        PartnerFeatureRequest.status.in_(['pending_payment', 'pending_review']),
    ))
    if pending:
        raise HTTPException(status_code=409, detail='Já existe uma solicitação pendente para esta funcionalidade')

    request = PartnerFeatureRequest(
        tenant_id=current_user.tenant_id,
        feature_key=data.feature_key,
        requested_by=current_user.id,
        quantity=data.quantity,
        unit_price=unit_price,
        total_price=round(unit_price * data.quantity, 2),
        billing_period=data.billing_period,
        payment_method=data.payment_method,
        status='pending_payment',
        notes=(data.notes or '').strip() or None,
    )
    db.add(request)
    await db.commit()
    await db.refresh(request)
    return {
        'id': request.id,
        'tenant_id': request.tenant_id,
        'feature_key': request.feature_key,
        'quantity': request.quantity,
        'unit_price': request.unit_price,
        'total_price': request.total_price,
        'billing_period': request.billing_period,
        'payment_method': request.payment_method,
        'status': request.status,
        'created_at': request.created_at.isoformat() + 'Z',
    }


@router.post('/feature-requests/{request_id}/receipt')
async def upload_partner_feature_receipt(
    request_id: str,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _ensure_partner_user(current_user)
    if current_user.role == UserRoleEnum.OPERATOR:
        raise HTTPException(status_code=403, detail='Somente o gestor pode enviar comprovante')
    item = await db.scalar(select(PartnerFeatureRequest).where(
        PartnerFeatureRequest.id == request_id,
        PartnerFeatureRequest.tenant_id == current_user.tenant_id,
    ))
    if item is None:
        raise HTTPException(status_code=404, detail='Solicitação não encontrada')
    if item.status != 'pending_payment':
        raise HTTPException(status_code=409, detail='Esta solicitação não aguarda comprovante')
    if file.content_type not in {'application/pdf', 'image/jpeg', 'image/png'}:
        raise HTTPException(status_code=422, detail='Anexe comprovante em PDF, JPG ou PNG')
    content = await file.read()
    if not content or len(content) > 30 * 1024 * 1024:
        raise HTTPException(status_code=413, detail='O comprovante deve ter até 30 MB')
    target_dir = Path('/app/storage/feature_requests') / current_user.tenant_id
    target_dir.mkdir(parents=True, exist_ok=True)
    suffix = Path(file.filename or 'receipt').suffix.lower()
    target = target_dir / f'{item.id}{suffix}'
    target.write_bytes(content)
    item.receipt_path = str(target)
    item.status = 'pending_review'
    await db.commit()
    return {'id': item.id, 'status': item.status, 'has_receipt': True}


def _feature_prices(item: PartnerFeatureEntitlement | None) -> dict[str, float]:
    if item is None:
        return {}
    try:
        values = json.loads(item.billing_prices or '{}')
    except json.JSONDecodeError:
        values = {}
    if not values and item.price > 0:
        values[item.billing_period] = item.price
    return {key: float(value) for key, value in values.items() if key in {'monthly', 'annual', 'one_time'}}


@router.post('/me/documents', status_code=201)
async def upload_partner_document(
    document_type: str,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _ensure_partner_user(current_user)
    document_type = document_type.strip().lower()
    if document_type not in PARTNER_DOCUMENT_TYPES:
        raise HTTPException(status_code=422, detail='Invalid partner document type')
    if file.content_type not in {'application/pdf', 'image/jpeg', 'image/png'}:
        raise HTTPException(status_code=422, detail='Document must be PDF, JPG or PNG')

    profile = await db.scalar(
        select(PartnerProfile).where(PartnerProfile.tenant_id == current_user.tenant_id)
    )
    if not profile:
        raise HTTPException(status_code=404, detail='Partner profile not found')
    expected = {'cnpj': {'alvara'}, 'cpf': {'rg', 'cnh'}}.get(profile.document_type)
    if expected and document_type not in expected:
        raise HTTPException(status_code=422, detail='Document type does not match the partner document')

    safe_name = Path(file.filename or 'document').name
    target_dir = Path('/app/storage/partner_documents') / current_user.tenant_id
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / safe_name
    target.write_bytes(await file.read())
    document = PartnerDocument(
        tenant_id=current_user.tenant_id,
        document_type=document_type,
        file_name=safe_name,
        storage_path=str(target),
    )
    db.add(document)
    profile.approval_status = 'documents_submitted'
    await db.commit()
    return {
        'id': document.id,
        'document_type': document_type,
        'file_name': safe_name,
        'approval_status': profile.approval_status,
    }


@router.get('/guide/parkings')
async def guide_parkings(
    city: str | None = Query(default=None, min_length=2),
    latitude: float | None = Query(default=None),
    longitude: float | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = await db.scalar(select(PartnerProfile).where(PartnerProfile.tenant_id == current_user.tenant_id))
    if current_user.role != UserRoleEnum.TOUR_GUIDE and (not profile or profile.service_type not in {'tour_guide', 'tourism_company'}):
        raise HTTPException(status_code=403, detail='Guide account required')
    await _ensure_partner_feature(db, current_user, 'guide_affiliations')
    links = (await db.scalars(select(GuideParkingLink).where(GuideParkingLink.guide_user_id == current_user.id))).all()
    linked = {link.parking_id: link for link in links}
    parkings = list((await db.scalars(select(Parking).where(Parking.is_active.is_(True)))).all())
    if city:
        city_key = city.strip().casefold()
        parkings = [parking for parking in parkings if city_key in parking.city.casefold()]
    if latitude is not None and longitude is not None:
        parkings.sort(key=lambda parking: (parking.lat - latitude) ** 2 + (parking.lng - longitude) ** 2)
    return [
        {
            'id': parking.id,
            'name': parking.name,
            'city': parking.city,
            'status': linked[parking.id].status if parking.id in linked else 'not_linked',
            'accepts_affiliates': parking.accepts_guide_affiliates,
            'link_id': linked[parking.id].id if parking.id in linked else None,
            'commission_type': linked[parking.id].commission_type if parking.id in linked else None,
            'commission_value': float(linked[parking.id].commission_value) if parking.id in linked and linked[parking.id].commission_value else None,
            'commission_terms': json.loads(linked[parking.id].commission_terms) if parking.id in linked and linked[parking.id].commission_terms else {},
            'offer_terms': json.loads(parking.guide_commission_terms) if parking.guide_commission_terms else {},
        }
        for parking in parkings
    ]


@router.post('/guide/parkings/{parking_id}')
async def request_guide_parking_link(
    parking_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = await db.scalar(select(PartnerProfile).where(PartnerProfile.tenant_id == current_user.tenant_id))
    if current_user.role != UserRoleEnum.TOUR_GUIDE and (not profile or profile.service_type not in {'tour_guide', 'tourism_company'}):
        raise HTTPException(status_code=403, detail='Guide account required')
    await _ensure_partner_feature(db, current_user, 'guide_affiliations')
    parking = await db.scalar(select(Parking).where(Parking.id == parking_id, Parking.is_active.is_(True)))
    if parking is None:
        raise HTTPException(status_code=404, detail='Parking not found')
    if not parking.accepts_guide_affiliates:
        raise HTTPException(status_code=409, detail='This partner is not accepting affiliate requests')
    existing = await db.scalar(select(GuideParkingLink).where(GuideParkingLink.guide_user_id == current_user.id, GuideParkingLink.parking_id == parking_id))
    if existing is None:
        existing = GuideParkingLink(id=str(uuid4()), guide_user_id=current_user.id, parking_id=parking_id, status='pending')
        db.add(existing)
        await db.commit()
    return {'parking_id': parking_id, 'status': existing.status}


@router.put('/parking-management/{parking_id}/guide-offer')
async def update_guide_offer(
    parking_id: str,
    data: GuideCommissionRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'guide_affiliations')
    parking = await db.scalar(select(Parking).where(Parking.id == parking_id, Parking.tenant_id == current_user.tenant_id))
    if parking is None:
        raise HTTPException(status_code=404, detail='Parking not found')
    terms = data.terms if data.terms is not None else (
        json.loads(parking.guide_commission_terms)
        if parking.guide_commission_terms
        else {'long_term': {'commission_type': data.commission_type, 'commission_value': data.commission_value}}
    )
    for period, term in terms.items():
        if period not in {'daily', 'weekly', 'monthly', 'long_term'} or term.get('commission_type') not in {'percentage', 'fixed'}:
            raise HTTPException(status_code=422, detail='Invalid commission offer')
        value = float(term.get('commission_value', 0))
        if value < 0 or (term.get('commission_type') == 'percentage' and value > 100):
            raise HTTPException(status_code=422, detail='Invalid commission offer value')
    accepts_affiliates = data.accepts_affiliates if data.accepts_affiliates is not None else parking.accepts_guide_affiliates
    required_periods = {'daily', 'weekly', 'monthly', 'long_term'}
    if accepts_affiliates and (
        set(terms) != required_periods
        or any(float(term.get('commission_value', 0)) <= 0 for term in terms.values())
    ):
        raise HTTPException(
            status_code=422,
            detail='Configure a positive affiliate commission for every parking plan before accepting affiliates',
        )
    parking.guide_commission_terms = json.dumps(terms)
    if data.accepts_affiliates is not None:
        parking.accepts_guide_affiliates = accepts_affiliates
    await db.commit()
    return {
        'parking_id': parking.id,
        'accepts_affiliates': parking.accepts_guide_affiliates,
        'offer_terms': terms,
    }


@router.get('/parking-management/{parking_id}/guide-offer')
async def get_guide_offer(
    parking_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'guide_affiliations')
    parking = await db.scalar(select(Parking).where(
        Parking.id == parking_id,
        Parking.tenant_id == current_user.tenant_id,
    ))
    if parking is None:
        raise HTTPException(status_code=404, detail='Parking not found')
    return {
        'parking_id': parking.id,
        'accepts_affiliates': parking.accepts_guide_affiliates,
        'offer_terms': json.loads(parking.guide_commission_terms) if parking.guide_commission_terms else {},
    }


@router.get('/guide/services')
async def list_guide_services(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = await db.scalar(select(PartnerProfile).where(PartnerProfile.tenant_id == current_user.tenant_id))
    if current_user.role != UserRoleEnum.TOUR_GUIDE and (not profile or profile.service_type != 'tour_guide'):
        raise HTTPException(status_code=403, detail='Guide account required')
    await _ensure_partner_feature(db, current_user, 'services_management')
    services = (await db.scalars(select(GuideService).where(GuideService.guide_user_id == current_user.id).order_by(GuideService.created_at.desc()))).all()
    return [_guide_service_payload(service) for service in services]


@router.post('/guide/services', status_code=201)
async def create_guide_service(
    data: GuideServiceRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = await db.scalar(select(PartnerProfile).where(PartnerProfile.tenant_id == current_user.tenant_id))
    if current_user.role != UserRoleEnum.TOUR_GUIDE and (not profile or profile.service_type != 'tour_guide'):
        raise HTTPException(status_code=403, detail='Guide account required')
    if not data.name.strip() or data.price < 0:
        raise HTTPException(status_code=422, detail='Invalid guide service')
    await _ensure_partner_feature(db, current_user, 'services_management')
    tenant_service_count = int(await db.scalar(
        select(func.count(GuideService.id)).join(User, User.id == GuideService.guide_user_id)
        .where(User.tenant_id == current_user.tenant_id)
    ) or 0)
    await _ensure_service_capacity(db, current_user.tenant_id, tenant_service_count + 1)
    service = GuideService(
        guide_user_id=current_user.id,
        name=data.name.strip(),
        description=data.description.strip() if data.description else None,
        price=data.price,
        duration_minutes=data.duration_minutes,
        schedule=json.dumps(data.schedule or {}),
        is_active=data.is_active,
    )
    db.add(service)
    await db.commit()
    await db.refresh(service)
    return _guide_service_payload(service)


@router.post('/guide/links/{link_id}/approve')
async def approve_guide_parking_link(
    link_id: str,
    data: GuideCommissionRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'guide_affiliations')
    if data.commission_type not in {'percentage', 'fixed'} or data.commission_value < 0:
        raise HTTPException(status_code=422, detail='Invalid commission terms')
    link = await db.scalar(select(GuideParkingLink).where(GuideParkingLink.id == link_id))
    if link is None:
        raise HTTPException(status_code=404, detail='Affiliation request not found')
    parking = await db.scalar(select(Parking).where(Parking.id == link.parking_id, Parking.tenant_id == current_user.tenant_id))
    if parking is None:
        raise HTTPException(status_code=403, detail='Parking does not belong to this partner')
    if not parking.accepts_guide_affiliates:
        raise HTTPException(status_code=409, detail='This partner is not accepting affiliates')
    if data.commission_type == 'percentage' and data.commission_value > 100:
        raise HTTPException(status_code=422, detail='Percentage commission cannot exceed 100')
    link.status = 'approved'
    link.commission_type = data.commission_type
    link.commission_value = str(data.commission_value)
    terms = data.terms or (json.loads(parking.guide_commission_terms) if parking.guide_commission_terms else {})
    for period, term in terms.items():
        if period not in {'daily', 'weekly', 'monthly', 'long_term'}:
            raise HTTPException(status_code=422, detail='Invalid commission period')
        if term.get('commission_type') not in {'percentage', 'fixed'} or float(term.get('commission_value', 0)) < 0:
            raise HTTPException(status_code=422, detail='Invalid commission period value')
        if term.get('commission_type') == 'percentage' and float(term.get('commission_value', 0)) > 100:
            raise HTTPException(status_code=422, detail='Percentage commission cannot exceed 100')
    link.commission_terms = json.dumps(terms) if terms else None
    await db.commit()
    return {
        'id': link.id,
        'parking_id': link.parking_id,
        'status': link.status,
        'commission_type': link.commission_type,
        'commission_value': float(link.commission_value),
        'commission_terms': terms,
    }


@router.get('/guide/requests')
async def list_guide_requests(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'guide_affiliations')
    result = await db.execute(
        select(GuideParkingLink, User, Parking)
        .join(User, User.id == GuideParkingLink.guide_user_id)
        .join(Parking, Parking.id == GuideParkingLink.parking_id)
        .where(Parking.tenant_id == current_user.tenant_id)
        .order_by(GuideParkingLink.created_at.desc())
    )
    return [
        {
            'id': link.id,
            'guide_name': guide.name,
            'guide_email': guide.email,
            'parking_id': parking.id,
            'parking_name': parking.name,
            'status': link.status,
            'commission_type': link.commission_type,
            'commission_value': float(link.commission_value) if link.commission_value else None,
            'commission_terms': json.loads(link.commission_terms) if link.commission_terms else {},
        }
        for link, guide, parking in result.all()
    ]


@router.get('/guide/dashboard')
async def guide_dashboard(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != UserRoleEnum.TOUR_GUIDE:
        raise HTTPException(status_code=403, detail='Guide account required')
    await _ensure_partner_feature(db, current_user, 'dashboard')
    indications = await db.scalar(select(func.count(Reservation.id)).where(Reservation.guide_user_id == current_user.id)) or 0
    completed_indications = await db.scalar(select(func.count(Reservation.id)).where(
        Reservation.guide_user_id == current_user.id,
        Reservation.status == 'completed',
    )) or 0
    pending_indications = await db.scalar(select(func.count(Reservation.id)).where(
        Reservation.guide_user_id == current_user.id,
        Reservation.status.notin_(['completed', 'cancelled', 'expired']),
    )) or 0
    reviews = (await db.scalars(select(GuideReview).where(GuideReview.guide_user_id == current_user.id))).all()
    average = round(sum(float(review.rating) for review in reviews) / len(reviews), 2) if reviews else 0
    payout = await db.scalar(select(func.coalesce(func.sum(Reservation.guide_payout_amount), 0)).where(
        Reservation.guide_user_id == current_user.id,
        Reservation.status == 'completed',
    )) or 0
    return {
        'indications': indications,
        'completed_indications': completed_indications,
        'pending_indications': pending_indications,
        'rating': average,
        'review_count': len(reviews),
        'total_payout': round(float(payout), 2),
    }


@router.post('/guide/reviews/{reservation_id}')
async def review_guide(
    reservation_id: str,
    data: GuideReviewRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not 1 <= data.rating <= 5:
        raise HTTPException(status_code=422, detail='Rating must be between 1 and 5')
    reservation = await db.scalar(select(Reservation).where(Reservation.id == reservation_id, Reservation.user_id == current_user.id))
    if reservation is None or reservation.guide_user_id is None or reservation.status not in {'checked_out', 'completed'}:
        raise HTTPException(status_code=422, detail='Only completed guide reservations can be reviewed')
    existing = await db.scalar(select(GuideReview).where(GuideReview.reservation_id == reservation_id))
    if existing:
        raise HTTPException(status_code=409, detail='Reservation already reviewed')
    review = GuideReview(guide_user_id=reservation.guide_user_id, reservation_id=reservation.id, customer_user_id=current_user.id, rating=str(data.rating), comment=data.comment)
    db.add(review)
    await db.commit()
    return {'rating': data.rating, 'status': 'recorded'}


@router.get("/parking-map")
async def get_partner_parking_map(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_staff(db, current_user)
    await _ensure_partner_feature(db, current_user, 'parking_operations')
    owned_query = select(Parking).where(Parking.tenant_id == current_user.tenant_id)
    if current_user.role == UserRoleEnum.OPERATOR:
        now = _now_schedule_local()
        assigned_ids = (await db.scalars(select(OperatorWorkShift.parking_id).where(
            OperatorWorkShift.operator_id == current_user.id,
            OperatorWorkShift.starts_at <= now,
            OperatorWorkShift.ends_at >= now,
        ))).all()
        owned_query = owned_query.where(Parking.id.in_(assigned_ids)) if assigned_ids else owned_query.where(Parking.id == "__none__")
    owned = (await db.scalars(owned_query.order_by(Parking.id).with_for_update())).all()
    for parking in owned:
        await expire_parking_reservations(db, parking)
    await db.commit()
    parkings = await ParkingManagementService.list_for_tenant(db, current_user.tenant_id)
    if current_user.role == UserRoleEnum.OPERATOR:
        allowed = {parking.id for parking in owned}
        parkings = [parking for parking in parkings if parking.id in allowed]
    if not parkings:
        return {"parkings": []}

    parking_ids = [parking.id for parking in parkings]
    reservations_result = await db.execute(
        select(Reservation, Vehicle, User)
        .join(Parking, Parking.id == Reservation.parking_id)
        .outerjoin(Vehicle, Vehicle.id == Reservation.vehicle_id)
        .outerjoin(User, User.id == Reservation.user_id)
        .where(Parking.tenant_id == current_user.tenant_id)
        .where(Reservation.parking_id.in_(parking_ids))
        .where(
            Reservation.status.in_(
                ["pre_reserved", "confirmed", "checked_in", "cancelled"]
            )
        )
        .order_by(Reservation.created_at.desc())
    )

    reservations_by_parking: dict[
        str, list[tuple[Reservation, Vehicle | None, User | None]]
    ] = {}
    for reservation, vehicle, customer in reservations_result.all():
        reservations_by_parking.setdefault(reservation.parking_id, []).append(
            (reservation, vehicle, customer)
        )

    return {
        "parkings": [
            _parking_layout_payload(
                parking,
                reservations_by_parking.get(parking.id or "", []),
            )
            for parking in parkings
        ]
    }


@router.post("/parking-map/{parking_id}/slots/{slot_code}/block")
async def toggle_parking_slot_block(
    parking_id: str,
    slot_code: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_staff(db, current_user)
    parking = await db.get(Parking, parking_id)
    if parking is None or parking.tenant_id != current_user.tenant_id:
        raise HTTPException(status_code=404, detail="Estacionamento não encontrado")
    if current_user.role == UserRoleEnum.OPERATOR:
        await _ensure_operator_on_parking_shift(db, current_user.id, parking_id)
    blocked = set(json.loads(parking.blocked_spots or "[]"))
    status = "available"
    if slot_code in blocked:
        blocked.remove(slot_code)
    else:
        blocked.add(slot_code)
        status = "blocked"
    parking.blocked_spots = json.dumps(sorted(blocked))
    await db.commit()
    return {"slot_code": slot_code, "status": status}


@router.get("/reservations")
async def list_partner_reservations(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_staff(db, current_user)
    await _ensure_any_partner_feature(
        db, current_user,
        ('parking_operations', 'cash_management_basic', 'dashboard', 'financial_management'),
    )
    cancellation_actor = aliased(User)
    reservation_query = select(Reservation, Parking, User, Vehicle, cancellation_actor.name).join(Parking, Parking.id == Reservation.parking_id).outerjoin(User, User.id == Reservation.user_id).outerjoin(Vehicle, Vehicle.id == Reservation.vehicle_id).outerjoin(cancellation_actor, cancellation_actor.id == Reservation.cancelled_by_user_id).where(Parking.tenant_id == current_user.tenant_id)
    if current_user.role == UserRoleEnum.OPERATOR:
        now = _now_schedule_local()
        assigned_ids = (await db.scalars(select(OperatorWorkShift.parking_id).where(
            OperatorWorkShift.operator_id == current_user.id,
            OperatorWorkShift.starts_at <= now,
            OperatorWorkShift.ends_at >= now,
        ))).all()
        reservation_query = reservation_query.where(Reservation.parking_id.in_(assigned_ids)) if assigned_ids else reservation_query.where(Reservation.parking_id == "__none__")
    result = await db.execute(
        reservation_query.order_by(Reservation.created_at.desc())
    )

    payload = []
    for reservation, parking, customer, vehicle, cancelled_by_name in result.all():
        excess_minutes, excess_amount = calculate_checkout_excess(reservation, parking)
        payload.append({
            "id": reservation.id,
            "parking_name": parking.name,
            "customer_name": "Cliente avulso" if reservation.walk_in_plate else (customer.name if customer else "Cliente nao informado"),
            "vehicle_plate": vehicle.plate if vehicle else reservation.walk_in_plate,
            "vehicle_label": f"{vehicle.brand} {vehicle.model}" if vehicle else None,
            "status": reservation.status,
            "cancelled_by_user_id": reservation.cancelled_by_user_id,
            "cancelled_by_name": cancelled_by_name,
            "payment_status": reservation.payment_status,
            "notification_status": reservation.notification_status,
            "spot_type": reservation.spot_type,
            "pricing_plan": reservation.pricing_plan,
            "route_minutes": reservation.route_minutes,
            "hold_expires_at": reservation.hold_expires_at.isoformat() + "Z",
            "base_amount": reservation.base_amount,
            "services_amount": reservation.services_amount,
            "platform_fee_amount": reservation.platform_fee_amount,
            "guide_user_id": reservation.guide_user_id,
            "guide_commission_amount": reservation.guide_commission_amount,
            "guide_platform_fee_amount": reservation.guide_platform_fee_amount,
            "guide_payout_amount": reservation.guide_payout_amount,
            "final_total": reservation.final_total,
            "checkout_excess_minutes": excess_minutes,
            "checkout_excess_amount": excess_amount,
            "checkout_grace_minutes": reservation.checkout_grace_minutes,
            "selected_services": _reservation_services(reservation),
            "created_at": reservation.created_at.isoformat() + "Z",
        })
    return payload


@router.get('/financial-report')
async def get_partner_financial_report(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Finance Pro report: manager-only and protected by admin entitlement."""
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'financial_management')
    return await list_partner_reservations(db, current_user)


@router.get("/operators", response_model=list[PartnerOperatorResponse])
async def list_partner_operators(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_staff(db, current_user)
    await _ensure_partner_feature(db, current_user, 'team_management')
    result = await db.execute(
        select(User)
        .where(User.tenant_id == current_user.tenant_id)
        .where(User.role == UserRoleEnum.OPERATOR)
        .order_by(User.created_at.desc())
    )
    return [_operator_response(user) for user in result.scalars().all()]


@router.post("/operators", response_model=PartnerOperatorResponse, status_code=201)
async def create_partner_operator(
    data: PartnerOperatorCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'team_management')

    if not data.accepted_terms:
        raise HTTPException(status_code=422, detail="Terms acceptance is required")

    if not data.name.strip():
        raise HTTPException(status_code=422, detail="Name is required")

    if not data.email.strip():
        raise HTTPException(status_code=422, detail="Email is required")

    if not _is_valid_email(data.email):
        raise HTTPException(status_code=422, detail="Invalid email format")

    if data.phone and not _is_valid_phone(data.phone):
        raise HTTPException(status_code=422, detail="Invalid phone format")

    if not _is_valid_password(data.password):
        raise HTTPException(
            status_code=422,
            detail="Password must have at least 8 characters, uppercase, lowercase and special character",
        )

    normalized_email = data.email.strip().lower()
    existing_result = await db.execute(select(User).where(User.email == normalized_email))
    if existing_result.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Email already registered")
    if data.cpf and await db.scalar(select(User.id).where(User.cpf == data.cpf)):
        raise HTTPException(status_code=409, detail="CPF já cadastrado")

    count_result = await db.execute(
        select(func.count(User.id))
        .where(User.tenant_id == current_user.tenant_id)
        .where(User.role == UserRoleEnum.OPERATOR)
    )
    operator_count = count_result.scalar_one()
    parking_count = await db.scalar(select(func.count(Parking.id)).where(Parking.tenant_id == current_user.tenant_id, Parking.is_active.is_(True)))
    approved_extra = await db.scalar(select(func.coalesce(func.sum(OperatorPackageRequest.quantity), 0)).where(
        OperatorPackageRequest.tenant_id == current_user.tenant_id,
        OperatorPackageRequest.status == "approved",
    )) or 0
    tenant = await db.get(Tenant, current_user.tenant_id)
    base_limit = (
        tenant.operator_limit_override if tenant and tenant.operator_limit_override is not None
        else max(FREE_OPERATOR_LIMIT, int(parking_count or 1) * FREE_OPERATOR_LIMIT)
    )
    operator_limit = int(base_limit) + int(approved_extra)
    if operator_count >= operator_limit:
        raise HTTPException(
            status_code=402,
            detail=f"Limite de operadores atingido ({operator_limit}). Solicite operadores adicionais no painel de equipe.",
        )

    permissions = data.permissions or DEFAULT_OPERATOR_PERMISSIONS
    invalid_permissions = [
        permission
        for permission in permissions
        if permission not in OPERATOR_PERMISSION_LABELS
    ]
    if invalid_permissions:
        raise HTTPException(
            status_code=422,
            detail=f"Invalid permissions: {', '.join(invalid_permissions)}",
        )

    operator = User(
        tenant_id=current_user.tenant_id,
        name=data.name.strip(),
        firt_name=data.name.strip().split(" ")[0],
        email=normalized_email,
        password_hash=hash_password(data.password),
        phone=data.phone,
        cpf=data.cpf,
        phone_verified=False,
        email_verified=True,
        role=UserRoleEnum.OPERATOR,
        permissions=json.dumps(permissions),
    )
    db.add(operator)
    await db.commit()
    await db.refresh(operator)
    return _operator_response(operator)


def _operator_package_payload(item: OperatorPackageRequest) -> dict:
    return {
        "id": item.id,
        "quantity": item.quantity,
        "package_type": item.package_type,
        "amount": item.amount,
        "status": item.status,
        "receipt_path": bool(item.receipt_path),
        "created_at": item.created_at.isoformat() + "Z",
    }


@router.post("/operator-packages/requests", status_code=201)
async def request_operator_package(
    data: OperatorPackageRequestCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'team_management')
    if data.quantity < 1 or data.quantity > 100:
        raise HTTPException(status_code=422, detail="A quantidade deve estar entre 1 e 100 operadores.")
    if data.package_type not in {"individual", "package"}:
        raise HTTPException(status_code=422, detail="Tipo de contratação inválido.")
    item = OperatorPackageRequest(
        tenant_id=current_user.tenant_id,
        requested_by=current_user.id,
        quantity=data.quantity,
        package_type=data.package_type,
        amount=max(0, data.amount),
        status="pending_payment",
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return _operator_package_payload(item)


@router.get("/operator-packages/requests")
async def list_operator_package_requests(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_partner(db, current_user)
    rows = (await db.scalars(select(OperatorPackageRequest).where(
        OperatorPackageRequest.tenant_id == current_user.tenant_id
    ).order_by(OperatorPackageRequest.created_at.desc()))).all()
    return [_operator_package_payload(row) for row in rows]


@router.post("/operator-packages/requests/{request_id}/receipt")
async def upload_operator_package_receipt(
    request_id: str,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'team_management')
    item = await db.scalar(select(OperatorPackageRequest).where(
        OperatorPackageRequest.id == request_id,
        OperatorPackageRequest.tenant_id == current_user.tenant_id,
    ))
    if item is None:
        raise HTTPException(status_code=404, detail="Solicitação não encontrada.")
    if file.content_type not in {"application/pdf", "image/jpeg", "image/png"}:
        raise HTTPException(status_code=422, detail="Anexe um comprovante em PDF, JPG ou PNG.")
    content = await file.read()
    if len(content) > 30 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="O comprovante deve ter no máximo 30 MB.")
    target_dir = Path("/app/storage/operator_packages") / current_user.tenant_id
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / f"{item.id}_{Path(file.filename or 'receipt').name}"
    target.write_bytes(content)
    item.receipt_path = str(target)
    item.status = "pending_review"
    await db.commit()
    return _operator_package_payload(item)

@router.get("/operators/{operator_id}/parkings")
async def operator_parkings(operator_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'team_management')
    operator = await db.scalar(select(User).where(User.id == operator_id, User.tenant_id == current_user.tenant_id, User.role == UserRoleEnum.OPERATOR))
    if operator is None: raise HTTPException(status_code=404, detail="Operador não encontrado")
    rows = (await db.scalars(select(OperatorParkingAssignment).where(OperatorParkingAssignment.operator_id == operator_id))).all()
    return [row.parking_id for row in rows]

@router.put("/operators/{operator_id}/parkings")
async def assign_operator_parkings(operator_id: str, data: OperatorParkingAssignmentRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'team_management')
    operator = await db.scalar(select(User).where(User.id == operator_id, User.tenant_id == current_user.tenant_id, User.role == UserRoleEnum.OPERATOR))
    if operator is None: raise HTTPException(status_code=404, detail="Operador não encontrado")
    requested_ids = list(dict.fromkeys(data.parking_ids))
    valid = (await db.scalars(select(Parking.id).where(Parking.tenant_id == current_user.tenant_id, Parking.id.in_(requested_ids)))).all() if requested_ids else []
    if set(valid) != set(requested_ids):
        raise HTTPException(status_code=422, detail="Uma ou mais unidades não pertencem a esta empresa.")
    await db.execute(delete(OperatorParkingAssignment).where(OperatorParkingAssignment.operator_id == operator_id))
    db.add_all([OperatorParkingAssignment(operator_id=operator_id, parking_id=parking_id) for parking_id in valid])
    await db.commit()
    saved = (await db.scalars(select(OperatorParkingAssignment.parking_id).where(OperatorParkingAssignment.operator_id == operator_id))).all()
    return {"operator_id": operator_id, "parking_ids": saved}

@router.get("/shifts")
async def list_operator_shifts(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    await _ensure_parking_staff(db, current_user)
    if current_user.role != UserRoleEnum.OPERATOR:
        await _ensure_partner_feature(db, current_user, 'team_management')
    query = select(OperatorWorkShift).outerjoin(User, User.id == OperatorWorkShift.operator_id).join(Parking, Parking.id == OperatorWorkShift.parking_id).where(Parking.tenant_id == current_user.tenant_id)
    if current_user.role == UserRoleEnum.OPERATOR:
        query = query.where(OperatorWorkShift.operator_id == current_user.id)
    rows = (await db.scalars(query.order_by(OperatorWorkShift.starts_at.desc()))).all()
    return [{"id": r.id, "operator_id": r.operator_id, "parking_id": r.parking_id, "starts_at": r.starts_at.isoformat(), "ends_at": r.ends_at.isoformat()} for r in rows]

@router.post("/shifts", status_code=201)
async def create_operator_shift(data: OperatorShiftRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'team_management')
    starts_at = _schedule_local(data.starts_at)
    ends_at = _schedule_local(data.ends_at)
    if ends_at <= starts_at: raise HTTPException(status_code=422, detail="Fim do turno deve ser posterior ao início")
    operator = await db.scalar(select(User).where(User.id == data.operator_id, User.tenant_id == current_user.tenant_id, User.role == UserRoleEnum.OPERATOR).with_for_update())
    parking = await db.scalar(select(Parking).where(Parking.id == data.parking_id, Parking.tenant_id == current_user.tenant_id))
    assigned = await db.scalar(select(OperatorParkingAssignment).where(OperatorParkingAssignment.operator_id == data.operator_id, OperatorParkingAssignment.parking_id == data.parking_id)) if data.operator_id else None
    if not parking or (data.operator_id and (not operator or not assigned)): raise HTTPException(status_code=422, detail="Operador não está associado a este estacionamento")
    if data.operator_id:
        await _ensure_operator_has_no_shift_conflict(db, data.operator_id, starts_at, ends_at)
    shift = OperatorWorkShift(operator_id=data.operator_id, parking_id=data.parking_id, starts_at=starts_at, ends_at=ends_at)
    db.add(shift); await db.commit(); await db.refresh(shift)
    return {"id": shift.id, "operator_id": shift.operator_id, "parking_id": shift.parking_id, "starts_at": shift.starts_at.isoformat(), "ends_at": shift.ends_at.isoformat()}

@router.delete("/shifts/{shift_id}", status_code=204)
async def cancel_operator_shift(shift_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'team_management')
    shift = await db.scalar(select(OperatorWorkShift).join(Parking, Parking.id == OperatorWorkShift.parking_id).where(OperatorWorkShift.id == shift_id, Parking.tenant_id == current_user.tenant_id))
    if shift is None: raise HTTPException(status_code=404, detail="Turno não encontrado")
    db.add(OperatorScheduleHistory(parking_id=shift.parking_id, changed_by=current_user.id, action="cancelled", details=json.dumps({"shift_id": shift_id})))
    await db.delete(shift); await db.commit()

@router.put("/shifts/{shift_id}")
async def update_operator_shift(shift_id: str, data: OperatorShiftUpdateRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Assign or edit a shift while keeping operators conflict-free across units."""
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'team_management')
    shift = await db.scalar(
        select(OperatorWorkShift)
        .join(Parking, Parking.id == OperatorWorkShift.parking_id)
        .where(
            OperatorWorkShift.id == shift_id,
            Parking.tenant_id == current_user.tenant_id,
        )
    )
    if shift is None:
        raise HTTPException(status_code=404, detail="Turno não encontrado")

    starts_at = _schedule_local(data.starts_at)
    ends_at = _schedule_local(data.ends_at)
    if ends_at <= starts_at:
        raise HTTPException(status_code=422, detail="Fim do turno deve ser posterior ao início")

    if data.operator_id:
        operator = await db.scalar(select(User).where(
            User.id == data.operator_id,
            User.tenant_id == current_user.tenant_id,
            User.role == UserRoleEnum.OPERATOR,
            User.is_active.is_(True),
        ).with_for_update())
        assigned = await db.scalar(select(OperatorParkingAssignment.id).where(
            OperatorParkingAssignment.operator_id == data.operator_id,
            OperatorParkingAssignment.parking_id == shift.parking_id,
        ))
        if operator is None or assigned is None:
            raise HTTPException(status_code=422, detail="Operador não está ativo e autorizado para esta unidade")
        await _ensure_operator_has_no_shift_conflict(
            db, data.operator_id, starts_at, ends_at, exclude_shift_id=shift.id,
        )

    previous = {
        "operator_id": shift.operator_id,
        "starts_at": shift.starts_at.isoformat(),
        "ends_at": shift.ends_at.isoformat(),
    }
    shift.operator_id = data.operator_id
    shift.starts_at = starts_at
    shift.ends_at = ends_at
    db.add(OperatorScheduleHistory(
        parking_id=shift.parking_id,
        changed_by=current_user.id,
        action="updated",
        details=json.dumps({"shift_id": shift.id, "before": previous, "after": {
            "operator_id": shift.operator_id,
            "starts_at": starts_at.isoformat(),
            "ends_at": ends_at.isoformat(),
        }}),
    ))
    await db.commit()
    await db.refresh(shift)
    return {"id": shift.id, "operator_id": shift.operator_id, "parking_id": shift.parking_id, "starts_at": shift.starts_at.isoformat(), "ends_at": shift.ends_at.isoformat()}

@router.get("/work-profiles")
async def list_work_profiles(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'team_management')
    rows = (await db.scalars(select(OperatorWorkProfile).join(User, User.id == OperatorWorkProfile.operator_id).where(User.tenant_id == current_user.tenant_id))).all()
    return [{"id": r.id, "operator_id": r.operator_id, "parking_id": r.parking_id, "daily_hours": r.daily_hours, "lunch_minutes": r.lunch_minutes, "days_off": r.days_off_list(), "work_modality": r.work_modality, "bank_hours": r.bank_hours} for r in rows]

@router.put("/work-profiles", status_code=200)
async def save_work_profile(data: OperatorWorkProfileRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'team_management')
    if data.work_modality not in {"8h", "12h", "24h"} or not 1 <= data.daily_hours <= 24 or not 0 <= data.lunch_minutes <= 180 or data.bank_hours < 0 or any(day < 0 or day > 6 for day in data.days_off):
        raise HTTPException(status_code=422, detail="Jornada ou folgas inválidas")
    operator = await db.scalar(select(User).where(User.id == data.operator_id, User.tenant_id == current_user.tenant_id, User.role == UserRoleEnum.OPERATOR))
    assigned = await db.scalar(select(OperatorParkingAssignment).where(OperatorParkingAssignment.operator_id == data.operator_id, OperatorParkingAssignment.parking_id == data.parking_id))
    if not operator or not assigned: raise HTTPException(status_code=422, detail="Operador não está associado a este estacionamento")
    profile = await db.scalar(select(OperatorWorkProfile).where(OperatorWorkProfile.operator_id == data.operator_id, OperatorWorkProfile.parking_id == data.parking_id))
    action = "updated" if profile else "created"
    if profile is None:
        profile = OperatorWorkProfile(operator_id=data.operator_id, parking_id=data.parking_id)
        db.add(profile)
    profile.daily_hours = data.daily_hours; profile.lunch_minutes = data.lunch_minutes; profile.days_off = json.dumps(sorted(set(data.days_off))); profile.work_modality = data.work_modality; profile.bank_hours = data.bank_hours
    db.add(OperatorScheduleHistory(parking_id=data.parking_id, changed_by=current_user.id, action=action, details=json.dumps({"operator_id": data.operator_id, "daily_hours": data.daily_hours, "lunch_minutes": data.lunch_minutes, "days_off": data.days_off, "work_modality": data.work_modality, "bank_hours": data.bank_hours})))
    await db.commit(); await db.refresh(profile)
    return {"id": profile.id, "operator_id": profile.operator_id, "parking_id": profile.parking_id, "daily_hours": profile.daily_hours, "lunch_minutes": profile.lunch_minutes, "days_off": profile.days_off_list(), "work_modality": profile.work_modality, "bank_hours": profile.bank_hours}

@router.get("/schedule-history")
async def schedule_history(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'team_management')
    rows = (await db.scalars(select(OperatorScheduleHistory).join(Parking, Parking.id == OperatorScheduleHistory.parking_id).where(Parking.tenant_id == current_user.tenant_id).order_by(OperatorScheduleHistory.created_at.desc()))).all()
    return [{"id": r.id, "parking_id": r.parking_id, "changed_by": r.changed_by, "action": r.action, "details": json.loads(r.details or "{}"), "created_at": r.created_at.isoformat()} for r in rows]

@router.post("/shifts/suggest")
async def suggest_operator_shifts(data: ShiftSuggestionRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Sugere uma escala rotativa; o gestor pode editar antes de confirmar."""
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'team_management')
    if data.ends_on < data.starts_on or not 1 <= data.daily_hours <= 24:
        raise HTTPException(status_code=422, detail="Período, operadores ou carga horária inválidos")
    parking = await db.scalar(select(Parking).where(Parking.id == data.parking_id, Parking.tenant_id == current_user.tenant_id))
    if parking is None: raise HTTPException(status_code=404, detail="Estacionamento não encontrado")
    assigned = (await db.scalars(select(OperatorParkingAssignment.operator_id).where(OperatorParkingAssignment.parking_id == data.parking_id, OperatorParkingAssignment.operator_id.in_(data.operator_ids)))).all()
    if len(assigned) != len(set(data.operator_ids)): raise HTTPException(status_code=422, detail="Todos os operadores precisam estar associados à unidade")
    regime = data.work_regime or getattr(parking, "work_regime", "commercial") or "commercial"
    if regime not in {"commercial", "three_shifts", "24h_on_3off", "administrative_8h"}:
        raise HTTPException(status_code=422, detail="Modelo de jornada inválido")
    duration = int(data.daily_hours * 60)
    configured_hours = json.loads(parking.operating_hours or '{}')
    if not configured_hours and regime not in {"three_shifts", "24h_on_3off"} and not (data.opening_time and data.closing_time):
        raise HTTPException(status_code=422, detail="Configure o funcionamento da unidade ou informe abertura e fechamento para gerar esta escala.")
    weekday_keys = ('mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun')
    suggestions = []
    local_start = _schedule_local(data.starts_on)
    local_end = _schedule_local(data.ends_on)
    day = local_start.replace(hour=0, minute=0, second=0, microsecond=0)
    end_day = local_end.replace(hour=0, minute=0, second=0, microsecond=0)
    index = 0
    rotation_cursor = 0
    last_24h_shift_day: dict[str, int] = {}
    conflicts = set()
    if data.operator_ids:
        conflict_window_start = max(day, _now_schedule_local())
        existing = (await db.scalars(select(OperatorWorkShift).where(
            OperatorWorkShift.operator_id.in_(data.operator_ids),
            OperatorWorkShift.starts_at < end_day + timedelta(days=1),
            OperatorWorkShift.ends_at > conflict_window_start,
        ))).all()
        conflicts = {shift.operator_id for shift in existing}
    conflict_operator_ids = sorted(conflicts)
    while day <= end_day:
        day_hours = None if regime in {"three_shifts", "24h_on_3off"} else configured_hours.get(weekday_keys[day.weekday()])
        if regime not in {"three_shifts", "24h_on_3off"} and not configured_hours and data.opening_time and data.closing_time:
            day_hours = {"open": data.opening_time, "close": data.closing_time}
        if regime not in {"three_shifts", "24h_on_3off"} and not day_hours:
            day += timedelta(days=1)
            continue
        candidates = [operator_id for operator_id in data.operator_ids if operator_id not in conflicts]
        slots: list[tuple[datetime, datetime]] = []
        if regime == "three_shifts":
            slots = [(day + timedelta(hours=slot * 8), day + timedelta(hours=(slot + 1) * 8)) for slot in range(3)]
        elif regime == "24h_on_3off":
            slots = [(day, day + timedelta(days=1))]
        else:
            open_text = day_hours.get('open', '08:00')
            hour, minute = (int(part) for part in open_text.split(':', 1))
            start = day.replace(hour=hour, minute=minute)
            close_text = day_hours.get('close', '18:00')
            close_hour, close_minute = (int(part) for part in close_text.split(':', 1))
            closing = day.replace(hour=close_hour, minute=close_minute)
            if closing <= start:
                closing += timedelta(days=1)
            operating_minutes = int((closing - start).total_seconds() // 60)
            max_shift_minutes = 8 * 60 if regime == "administrative_8h" else duration
            slot_count = max(1, (operating_minutes + max_shift_minutes - 1) // max_shift_minutes)
            # Overlap shift starts to avoid a gap when the opening window is
            # longer than one employee's configured workday.
            for slot in range(slot_count):
                slot_start = start + timedelta(minutes=min(slot * max_shift_minutes, max(operating_minutes - 60, 0)))
                slot_end = min(slot_start + timedelta(minutes=max_shift_minutes), closing)
                slots.append((slot_start, slot_end))

        for slot_number, (slot_start, slot_end) in enumerate(slots):
            if regime == "24h_on_3off":
                operator_id = None
                if candidates:
                    for offset in range(len(candidates)):
                        candidate_index = (rotation_cursor + offset) % len(candidates)
                        candidate_id = candidates[candidate_index]
                        last_day = last_24h_shift_day.get(candidate_id, -4)
                        if index - last_day >= 4:
                            operator_id = candidate_id
                            last_24h_shift_day[candidate_id] = index
                            rotation_cursor = (candidate_index + 1) % len(candidates)
                            break
            elif regime == "three_shifts":
                operator_id = candidates[(index + slot_number) % len(candidates)] if candidates and slot_number < len(candidates) else None
            else:
                operator_id = candidates[(index + slot_number) % len(candidates)] if candidates and slot_number < len(candidates) else None
            suggestions.append({"operator_id": operator_id, "starts_at": slot_start.isoformat(), "ends_at": slot_end.isoformat(), "work_regime": regime})
        index += 1
        day += timedelta(days=1)
    required_people = 3 if regime == "three_shifts" else (4 if regime == "24h_on_3off" else 1)
    warning = None
    if regime == "three_shifts" and len(data.operator_ids) < required_people:
        warning = "Cobertura pendente: três faixas de 8h foram criadas por dia. Os turnos sem operador continuam abertos para atribuição posterior."
    elif regime == "24h_on_3off" and len(data.operator_ids) < 4:
        warning = "A jornada 24h + 3 dias de folga deixa dias descobertos com menos de quatro operadores. Os dias sem operador aparecem como turnos abertos."
    if conflict_operator_ids:
        conflict_names = (await db.scalars(select(User.name).where(User.id.in_(conflict_operator_ids)))).all()
        warning = " ".join(filter(None, [warning, "Operadores já escalados em outra unidade no período foram removidos desta sugestão: " + ", ".join(conflict_names) + "."])).strip()
    return {"parking_id": data.parking_id, "work_regime": regime, "suggestions": suggestions, "required_people": required_people, "coverage_warning": warning, "conflicting_operator_ids": conflict_operator_ids, "rule": "A escala respeita a jornada escolhida. Turnos descobertos permanecem abertos; conflitos futuros em outra unidade não são atribuídos."}


@router.get(
    "/parking-management",
    response_model=list[ParkingManagementResponse],
)
async def list_managed_parkings(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'parking_management')
    return await ParkingManagementService.list_for_tenant(db, current_user.tenant_id)


@router.post(
    "/parking-management",
    response_model=ParkingManagementResponse,
    status_code=201,
)
async def create_managed_parking(
    data: ParkingManagementRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'parking_management')
    await _ensure_unit_capacity(db, current_user.tenant_id)
    if data.services:
        await _ensure_partner_feature(db, current_user, 'services_management')
    await _ensure_service_capacity(db, current_user.tenant_id, len(data.services))
    return await ParkingManagementService.create_for_tenant(
        db, current_user.tenant_id, data,
    )


@router.get(
    "/parking-management/{parking_id}",
    response_model=ParkingManagementResponse,
)
async def get_managed_parking(
    parking_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'parking_management')
    return await ParkingManagementService.get_for_tenant(
        db,
        current_user.tenant_id,
        parking_id,
    )


@router.put(
    "/parking-management/{parking_id}",
    response_model=ParkingManagementResponse,
)
async def update_managed_parking(
    parking_id: str,
    data: ParkingManagementRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_partner(db, current_user)
    await _ensure_partner_feature(db, current_user, 'parking_management')
    current = await db.scalar(select(Parking).where(
        Parking.id == parking_id, Parking.tenant_id == current_user.tenant_id
    ))
    if current is None:
        raise HTTPException(status_code=404, detail='Estacionamento não encontrado')
    current_service_rows = (await db.scalars(select(ParkingService).where(
        ParkingService.parking_id == parking_id
    ))).all()
    current_services = len(current_service_rows)
    old_service_data = sorted(
        (service.code, service.name, float(service.price), bool(service.is_active))
        for service in current_service_rows
    )
    new_service_data = sorted(
        (service.code, service.name, float(service.price), bool(service.is_active))
        for service in data.services
    )
    if old_service_data != new_service_data:
        await _ensure_partner_feature(db, current_user, 'services_management')
    total_services = int(await db.scalar(
        select(func.count(ParkingService.id)).join(Parking, Parking.id == ParkingService.parking_id)
        .where(Parking.tenant_id == current_user.tenant_id)
    ) or 0)
    await _ensure_service_capacity(
        db, current_user.tenant_id, max(
            0, total_services - current_services + sum(1 for service in data.services if service.is_active)
        )
    )
    return await ParkingManagementService.update_for_tenant(
        db, current_user.tenant_id, parking_id, data,
    )


async def _ensure_partner_feature(db: AsyncSession, user: User, key: str) -> dict:
    profile = await db.scalar(select(PartnerProfile).where(PartnerProfile.tenant_id == user.tenant_id))
    feature = feature_by_key(profile.service_type if profile else None, key)
    if feature is None:
        raise HTTPException(status_code=403, detail={'code': 'feature_unavailable', 'feature_key': key})
    entitlement = await db.scalar(select(PartnerFeatureEntitlement).where(
        PartnerFeatureEntitlement.tenant_id == user.tenant_id,
        PartnerFeatureEntitlement.feature_key == key,
    ))
    enabled = entitlement.is_enabled if entitlement else feature['default_is_enabled']
    if entitlement and entitlement.expires_at and entitlement.expires_at.replace(tzinfo=None) <= datetime.utcnow():
        enabled = False
    if not enabled:
        raise HTTPException(status_code=403, detail={
            'code': 'feature_locked', 'feature_key': key, 'name': feature['name'],
            'is_paid': entitlement.is_paid if entitlement else feature['default_is_paid'],
            'price': entitlement.price if entitlement else 0,
            'billing_period': entitlement.billing_period if entitlement else feature['default_billing_period'],
            'billing_prices': _feature_prices(entitlement),
        })
    return feature


async def _ensure_any_partner_feature(db: AsyncSession, user: User, keys: tuple[str, ...]):
    errors = []
    for key in keys:
        try:
            await _ensure_partner_feature(db, user, key)
            return
        except HTTPException as error:
            errors.append(error.detail)
    raise HTTPException(status_code=403, detail={'code': 'features_locked', 'features': errors})


async def _feature_request_price(
    db: AsyncSession, tenant_id: str, key: str
) -> tuple[bool, float, bool]:
    profile = await db.scalar(select(PartnerProfile).where(PartnerProfile.tenant_id == tenant_id))
    feature = feature_by_key(profile.service_type if profile else None, key)
    entitlement = await db.scalar(select(PartnerFeatureEntitlement).where(
        PartnerFeatureEntitlement.tenant_id == tenant_id, PartnerFeatureEntitlement.feature_key == key
    ))
    return (
        entitlement.is_paid,
        float(entitlement.price),
        entitlement.is_enabled,
    ) if entitlement else (
        bool(feature and feature['default_is_paid']),
        0.0,
        bool(feature and feature['default_is_enabled']),
    )


async def _ensure_service_capacity(db: AsyncSession, tenant_id: str, requested_total: int):
    approved_capacity = int(await db.scalar(select(func.max(PartnerFeatureRequest.capacity_after)).where(
        PartnerFeatureRequest.tenant_id == tenant_id, PartnerFeatureRequest.feature_key == 'additional_services',
        PartnerFeatureRequest.status == 'approved',
    )) or 1)
    current_count = int(await db.scalar(
        select(func.count(ParkingService.id))
        .join(Parking, Parking.id == ParkingService.parking_id)
        .where(Parking.tenant_id == tenant_id)
    ) or 0)
    paid, price, enabled = await _feature_request_price(db, tenant_id, 'additional_services')
    capacity = (max(current_count, approved_capacity) if enabled else max(current_count, 1)) if paid else 1_000_000
    if requested_total > capacity:
        raise HTTPException(status_code=402, detail={
            'code': 'feature_slots_required', 'feature_key': 'additional_services',
            'quantity': requested_total - capacity, 'unit_price': price,
            'message': 'O primeiro serviço está incluído. Solicite vagas adicionais para cadastrar mais serviços.',
        })


async def _ensure_unit_capacity(db: AsyncSession, tenant_id: str):
    total = int(await db.scalar(select(func.count(Parking.id)).where(Parking.tenant_id == tenant_id)) or 0)
    approved_capacity = int(await db.scalar(select(func.max(PartnerFeatureRequest.capacity_after)).where(
        PartnerFeatureRequest.tenant_id == tenant_id, PartnerFeatureRequest.feature_key == 'additional_units',
        PartnerFeatureRequest.status == 'approved',
    )) or 1)
    paid, price, enabled = await _feature_request_price(db, tenant_id, 'additional_units')
    capacity = (max(total, approved_capacity) if enabled else max(total, 1)) if paid else 1_000_000
    if total >= capacity:
        raise HTTPException(status_code=402, detail={
            'code': 'feature_slots_required', 'feature_key': 'additional_units',
            'quantity': 1, 'unit_price': price,
            'message': 'Solicite uma unidade adicional para cadastrar outro estacionamento.',
        })


def _ensure_parking_manager(user: User):
    if user.role not in {
        UserRoleEnum.PARTNER_MANAGER,
        UserRoleEnum.PARKING_ADMIN,
    }:
        raise HTTPException(status_code=403, detail="Insufficient permissions")

    if not user.tenant_id:
        raise HTTPException(status_code=403, detail="Tenant required")


def _operator_response(user: User) -> PartnerOperatorResponse:
    return PartnerOperatorResponse(
        id=user.id,
        name=user.name,
        email=user.email,
        phone=user.phone,
        cpf=user.cpf,
        role=user.role.value,
        permissions=_user_permissions(user),
        is_active=user.is_active,
        created_at=user.created_at.isoformat() + "Z",
    )


def _schedule_local(value: datetime) -> datetime:
    """Schedule times are wall-clock times in Brazil; DB stores them as naive local values."""
    if value.tzinfo is None:
        return value
    return value.astimezone(ZoneInfo("America/Sao_Paulo")).replace(tzinfo=None)


def _now_schedule_local() -> datetime:
    return datetime.now(ZoneInfo("America/Sao_Paulo")).replace(tzinfo=None)


async def _ensure_operator_has_no_shift_conflict(
    db: AsyncSession, operator_id: str, starts_at: datetime, ends_at: datetime,
    exclude_shift_id: str | None = None,
) -> None:
    query = select(OperatorWorkShift.id).where(
        OperatorWorkShift.operator_id == operator_id,
        OperatorWorkShift.starts_at < ends_at,
        OperatorWorkShift.ends_at > starts_at,
    )
    if exclude_shift_id:
        query = query.where(OperatorWorkShift.id != exclude_shift_id)
    conflict = await db.scalar(query.limit(1))
    if conflict:
        raise HTTPException(status_code=409, detail="Este operador já possui um turno sobreposto em outra unidade ou nesta mesma unidade.")


async def _ensure_operator_on_parking_shift(
    db: AsyncSession, operator_id: str, parking_id: str,
) -> None:
    now = _now_schedule_local()
    shift_id = await db.scalar(select(OperatorWorkShift.id).where(
        OperatorWorkShift.operator_id == operator_id,
        OperatorWorkShift.parking_id == parking_id,
        OperatorWorkShift.starts_at <= now,
        OperatorWorkShift.ends_at >= now,
    ).limit(1))
    if shift_id is None:
        raise HTTPException(status_code=403, detail="Você só pode operar esta unidade durante o seu turno escalado.")


def _guide_service_payload(service: GuideService) -> dict:
    return {
        'id': service.id,
        'name': service.name,
        'description': service.description,
        'price': service.price,
        'duration_minutes': service.duration_minutes,
        'schedule': json.loads(service.schedule) if service.schedule else {},
        'is_active': service.is_active,
    }


def _user_permissions(user: User) -> list[str]:
    if user.role in {
        UserRoleEnum.PARTNER_MANAGER,
        UserRoleEnum.PARKING_ADMIN,
        UserRoleEnum.SUPER_ADMIN,
    }:
        return OWNER_PERMISSIONS

    if user.role == UserRoleEnum.OPERATOR:
        if user.permissions:
            try:
                values = json.loads(user.permissions)
            except json.JSONDecodeError:
                return DEFAULT_OPERATOR_PERMISSIONS

            if isinstance(values, list):
                return [
                    permission
                    for permission in values
                    if isinstance(permission, str)
                    and permission in OPERATOR_PERMISSION_LABELS
                ]

        return DEFAULT_OPERATOR_PERMISSIONS

    return []


def _is_valid_email(value: str) -> bool:
    return bool(re.match(r"^[^\s@]+@[^\s@]+\.[^\s@]+$", value.strip()))


def _is_valid_phone(value: str) -> bool:
    digits = re.sub(r"\D", "", value)
    return 10 <= len(digits) <= 11


def _is_valid_password(value: str) -> bool:
    return (
        len(value) >= 8
        and bool(re.search(r"[A-Z]", value))
        and bool(re.search(r"[a-z]", value))
        and bool(re.search(r"[^A-Za-z0-9]", value))
    )


async def _ensure_parking_partner(db: AsyncSession, user: User):
    _ensure_parking_manager(user)
    await _ensure_parking_profile(db, user)


async def _ensure_parking_staff(db: AsyncSession, user: User):
    if user.role not in {
        UserRoleEnum.PARTNER_MANAGER,
        UserRoleEnum.PARKING_ADMIN,
        UserRoleEnum.OPERATOR,
    }:
        raise HTTPException(status_code=403, detail="Insufficient permissions")

    if not user.tenant_id:
        raise HTTPException(status_code=403, detail="Tenant required")

    await _ensure_parking_profile(db, user)


async def _ensure_parking_profile(db: AsyncSession, user: User):
    if not user.tenant_id:
        raise HTTPException(status_code=403, detail="Tenant required")

    profile_result = await db.execute(
        select(PartnerProfile).where(PartnerProfile.tenant_id == user.tenant_id)
    )
    profile = profile_result.scalar_one_or_none()

    if not profile or profile.service_type != "parking":
        raise HTTPException(status_code=403, detail="Parking partner required")


def _parking_layout_payload(
    parking: ParkingManagementResponse,
    reservations: list[tuple[Reservation, Vehicle | None, User | None]],
):
    active_reservations = [
        item
        for item in reservations
        if item[0].status in {"pre_reserved", "confirmed", "checked_in"}
    ]
    cancelled = [item for item in reservations if item[0].status == "cancelled"]
    active_by_slot: dict[str, tuple[Reservation, Vehicle | None, User | None]] = {}
    fallback_reservations: list[tuple[Reservation, Vehicle | None, User | None]] = []
    for item in active_reservations:
        reservation = item[0]
        if reservation.spot_code:
            active_by_slot[reservation.spot_code] = item
        else:
            fallback_reservations.append(item)

    reserved = [
        item for item in active_reservations if item[0].status != "checked_in"
    ]
    occupied = [
        item for item in active_reservations if item[0].status == "checked_in"
    ]
    pre_reserved_amount = sum(
        item[0].final_total
        for item in active_reservations
        if item[0].status == "pre_reserved"
    )
    confirmed_amount = sum(
        item[0].final_total
        for item in active_reservations
        if item[0].status == "confirmed"
    )
    checked_in_amount = sum(
        item[0].final_total
        for item in active_reservations
        if item[0].status == "checked_in"
    )
    cancelled_amount = sum(item[0].final_total for item in cancelled)
    pending_payment_amount = sum(
        item[0].final_total
        for item in active_reservations
        if item[0].payment_status != "paid"
    )
    paid_amount = sum(
        item[0].final_total
        for item in active_reservations
        if item[0].payment_status == "paid"
    )
    services_amount_by_status = {
        "pre_reserved": sum(
            item[0].services_amount
            for item in active_reservations
            if item[0].status == "pre_reserved"
        ),
        "confirmed": sum(
            item[0].services_amount
            for item in active_reservations
            if item[0].status == "confirmed"
        ),
        "checked_in": sum(
            item[0].services_amount
            for item in active_reservations
            if item[0].status == "checked_in"
        ),
        "cancelled": sum(item[0].services_amount for item in cancelled),
    }
    slots = []
    fallback_index = 0

    for index in range(1, parking.total_spots + 1):
        code = f"V{index:03d}"
        blocked_codes = set(parking.blocked_spots)
        assigned = active_by_slot.get(code)
        if assigned is None and fallback_index < len(fallback_reservations):
            assigned = fallback_reservations[fallback_index]
            fallback_index += 1

        slot_type = _slot_type(index, parking)
        if assigned is None:
            slots.append(
                {
                    "code": code,
                    "type": slot_type,
                    "status": "blocked" if code in blocked_codes else "free",
                    "reservation": None,
                }
            )
            continue

        reservation, vehicle, customer = assigned
        status = "occupied" if reservation.status == "checked_in" else "pre_reserved"
        slots.append(
            _slot_payload(code, slot_type, status, reservation, vehicle, customer, parking)
        )

    return {
        "id": parking.id,
        "name": parking.name,
        "uncovered_pricing": {
            "first_hour_price": parking.uncovered_pricing.first_hour_price,
            "additional_hour_price": parking.uncovered_pricing.additional_hour_price,
            "daily_price": parking.uncovered_pricing.daily_price,
            "weekly_price": parking.uncovered_pricing.weekly_price,
            "monthly_price": parking.uncovered_pricing.monthly_price,
        },
        "covered_pricing": {
            "first_hour_price": parking.covered_pricing.first_hour_price,
            "additional_hour_price": parking.covered_pricing.additional_hour_price,
            "daily_price": parking.covered_pricing.daily_price,
            "weekly_price": parking.covered_pricing.weekly_price,
            "monthly_price": parking.covered_pricing.monthly_price,
        },
        "category_pricing": {
            key: value.model_dump() for key, value in parking.category_pricing.items()
        },
        "total_spots": parking.total_spots,
        "available_spots": sum(1 for slot in slots if slot["status"] == "free"),
        "pre_reserved_spots": len(reserved),
        "occupied_spots": len(occupied),
        "cancelled_spots": len(cancelled),
        "pre_reserved_amount": pre_reserved_amount,
        "confirmed_amount": confirmed_amount,
        "checked_in_amount": checked_in_amount,
        "cancelled_amount": cancelled_amount,
        "pending_payment_amount": pending_payment_amount,
        "paid_amount": paid_amount,
        "services_amount_by_status": services_amount_by_status,
        "slots": slots,
    }


def _slot_payload(
    code: str,
    slot_type: str,
    status: str,
    reservation: Reservation,
    vehicle: Vehicle | None,
    customer: User | None,
    parking: ParkingManagementResponse,
):
    checkout_excess_minutes, checkout_excess_amount = _checkout_excess_preview(
        reservation,
        slot_type,
        parking,
    )
    if reservation.checkout_excess_paid_at is not None:
        checkout_excess_amount = reservation.checkout_excess_amount

    return {
        "code": reservation.spot_code or code,
        "type": slot_type,
        "status": status,
        "reservation": {
            "id": reservation.id,
            "status": reservation.status,
            "payment_status": reservation.payment_status,
            "spot_type": reservation.spot_type,
            "pricing_plan": reservation.pricing_plan,
            "duration_hours": reservation.duration_hours,
            "base_amount": reservation.base_amount,
            "services_amount": reservation.services_amount,
            "platform_fee_amount": reservation.platform_fee_amount,
            "guide_user_id": reservation.guide_user_id,
            "guide_commission_amount": reservation.guide_commission_amount,
            "guide_platform_fee_amount": reservation.guide_platform_fee_amount,
            "guide_payout_amount": reservation.guide_payout_amount,
            "final_total": reservation.final_total,
            "selected_services": _reservation_services(reservation),
            "customer_name": "Cliente avulso" if reservation.walk_in_plate else (customer.name if customer else "Cliente nao informado"),
            "customer_phone": reservation.walk_in_phone or (customer.phone if customer else None),
            "vehicle_plate": vehicle.plate if vehicle else reservation.walk_in_plate,
            "vehicle_label": f"{vehicle.brand} {vehicle.model}" if vehicle else None,
            "route_minutes": reservation.route_minutes,
            "created_at": reservation.created_at.isoformat() + "Z",
            "checked_in_at": reservation.checked_in_at.isoformat() + "Z"
            if reservation.checked_in_at
            else None,
            "arrival_estimate_at": (
                reservation.arrival_estimate_at
                or reservation.created_at + timedelta(minutes=reservation.route_minutes)
            ).isoformat() + "Z",
            "is_manual_arrival": reservation.is_manual_arrival,
            "hold_expires_at": reservation.hold_expires_at.isoformat() + "Z",
            "cancelled_at": reservation.cancelled_at.isoformat() + "Z"
            if reservation.cancelled_at
            else None,
            "cancellation_fee_amount": reservation.cancellation_fee_amount,
            "cancellation_credit_amount": reservation.cancellation_credit_amount,
            "checkout_grace_minutes": reservation.checkout_grace_minutes,
            "checkout_excess_minutes": checkout_excess_minutes,
            "checkout_excess_amount": checkout_excess_amount,
            "checkout_excess_paid_at": reservation.checkout_excess_paid_at.isoformat() + "Z"
            if reservation.checkout_excess_paid_at
            else None,
        },
    }


def _slot_type(index: int, parking: ParkingManagementResponse) -> str:
    return physical_spot_type(index, parking)


def _reservation_services(reservation: Reservation) -> list[dict]:
    if not reservation.selected_services_snapshot:
        return []

    try:
        services = json.loads(reservation.selected_services_snapshot)
    except json.JSONDecodeError:
        return []

    return services if isinstance(services, list) else []


def _checkout_excess_preview(
    reservation: Reservation,
    slot_type: str,
    parking: ParkingManagementResponse,
) -> tuple[int, float]:
    if (
        reservation.status != "checked_in"
        or reservation.checked_in_at is None
        or reservation.pricing_plan != "hourly"
    ):
        return reservation.checkout_excess_minutes, reservation.checkout_excess_amount

    elapsed_minutes = max(
        int(
            (
                datetime.utcnow() - reservation.checked_in_at.replace(tzinfo=None)
            ).total_seconds()
            // 60
        ),
        0,
    )
    grace_minutes = reservation.checkout_grace_minutes or 15
    included_minutes = reservation.duration_hours * 60 + grace_minutes
    excess_minutes = max(elapsed_minutes - included_minutes, 0)
    if excess_minutes == 0:
        return 0, 0

    configured = parking.category_pricing.get(reservation.spot_type)
    if configured:
        hourly_amount = configured.additional_hour_price or configured.first_hour_price
    elif reservation.spot_type in {"covered", "vip"}:
        hourly_amount = parking.covered_pricing.additional_hour_price
    else:
        hourly_amount = parking.uncovered_pricing.additional_hour_price
    return excess_minutes, round(ceil(excess_minutes / 60) * hourly_amount, 2)


def _ensure_partner_user(user: User):
    if user.role not in {
        UserRoleEnum.PARTNER_MANAGER,
        UserRoleEnum.PARKING_ADMIN,
        UserRoleEnum.OPERATOR,
        UserRoleEnum.TOUR_GUIDE,
        UserRoleEnum.SUPER_ADMIN,
    }:
        raise HTTPException(status_code=403, detail="Insufficient permissions")

    if not user.tenant_id:
        raise HTTPException(status_code=403, detail="Tenant required")


@router.get("/fee-statement")
async def partner_fee_statement(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    await _ensure_parking_partner(db, current_user)
    debts = (await db.scalars(select(PartnerFeeDebt).where(
        PartnerFeeDebt.tenant_id == current_user.tenant_id
    ).order_by(PartnerFeeDebt.created_at.desc()))).all()
    settlements = (await db.execute(select(PartnerFeeSettlement, PartnerFeeDebt).join(
        PartnerFeeDebt, PartnerFeeDebt.id == PartnerFeeSettlement.debt_id
    ).where(PartnerFeeDebt.tenant_id == current_user.tenant_id))).all()
    return {
        "pending_total": float(sum(d.remaining_amount for d in debts)),
        "debts": [{"id": d.id, "reservation_id": d.reservation_id,
            "description": d.description, "amount": float(d.amount),
            "remaining_amount": float(d.remaining_amount),
            "created_at": d.created_at.isoformat() + "Z"} for d in debts],
        "settlements": [{"debt_id": s.debt_id, "payment_id": s.payment_id,
            "reservation_id": d.reservation_id, "amount": float(s.amount),
            "created_at": s.created_at.isoformat() + "Z"} for s, d in settlements],
    }
