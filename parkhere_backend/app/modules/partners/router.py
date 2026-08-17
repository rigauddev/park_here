import json
import re
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy import func
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.core.database import get_db
from app.core.security import hash_password
from app.modules.auth.auth_service import AuthService
from app.modules.auth.schemas import PartnerSignupRequest
from app.modules.customer_assets.models import Vehicle
from app.modules.parkings.models import Parking
from app.modules.parkings.schemas import (
    ParkingManagementRequest,
    ParkingManagementResponse,
)
from app.modules.parkings.service import ParkingManagementService
from app.modules.partners.models import PartnerProfile
from app.modules.payments.models import PartnerPaymentAccount
from app.modules.reservations.models import Reservation
from app.modules.users.models.user_model import User
from app.modules.users.models.user_model_role_enum import UserRoleEnum

router = APIRouter(prefix="/partners", tags=["Partners"])

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
    password: str
    accepted_terms: bool
    permissions: list[str] | None = None


class PartnerOperatorResponse(BaseModel):
    id: str
    name: str
    email: str
    phone: str | None
    role: str
    permissions: list[str]
    is_active: bool
    created_at: str


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
        cnpj=data.cnpj,
        registration_status=data.registration_status,
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

    return {
        "tenant_id": current_user.tenant_id,
        "role": current_user.role.value,
        "permissions": _user_permissions(current_user),
        "available_operator_permissions": OPERATOR_PERMISSION_LABELS,
        "user_email": current_user.email,
        "service_type": profile.service_type if profile else None,
        "company_name": profile.company_name if profile else None,
        "approval_status": profile.approval_status
        if profile
        else "missing_profile",
        "payment_account": {
            "provider": payment_account.provider,
            "status": payment_account.status,
            "account_label": payment_account.account_label,
        }
        if payment_account
        else None,
    }


@router.get("/parking-map")
async def get_partner_parking_map(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_staff(db, current_user)
    parkings = await ParkingManagementService.list_for_tenant(db, current_user.tenant_id)
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


@router.get("/reservations")
async def list_partner_reservations(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_staff(db, current_user)
    result = await db.execute(
        select(Reservation, Parking, User, Vehicle)
        .join(Parking, Parking.id == Reservation.parking_id)
        .outerjoin(User, User.id == Reservation.user_id)
        .outerjoin(Vehicle, Vehicle.id == Reservation.vehicle_id)
        .where(Parking.tenant_id == current_user.tenant_id)
        .order_by(Reservation.created_at.desc())
    )

    return [
        {
            "id": reservation.id,
            "parking_name": parking.name,
            "customer_name": customer.name if customer else "Cliente nao informado",
            "vehicle_plate": vehicle.plate if vehicle else None,
            "vehicle_label": f"{vehicle.brand} {vehicle.model}" if vehicle else None,
            "status": reservation.status,
            "payment_status": reservation.payment_status,
            "notification_status": reservation.notification_status,
            "spot_type": reservation.spot_type,
            "pricing_plan": reservation.pricing_plan,
            "route_minutes": reservation.route_minutes,
            "hold_expires_at": reservation.hold_expires_at.isoformat(),
            "base_amount": reservation.base_amount,
            "services_amount": reservation.services_amount,
            "platform_fee_amount": reservation.platform_fee_amount,
            "final_total": reservation.final_total,
            "selected_services": _reservation_services(reservation),
            "created_at": reservation.created_at.isoformat(),
        }
        for reservation, parking, customer, vehicle in result.all()
    ]


@router.get("/operators", response_model=list[PartnerOperatorResponse])
async def list_partner_operators(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_staff(db, current_user)
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

    count_result = await db.execute(
        select(func.count(User.id))
        .where(User.tenant_id == current_user.tenant_id)
        .where(User.role == UserRoleEnum.OPERATOR)
    )
    operator_count = count_result.scalar_one()
    if operator_count >= FREE_OPERATOR_LIMIT:
        raise HTTPException(
            status_code=402,
            detail="Free plan includes up to 2 operators. Extra operators require an additional fee.",
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
        phone_verified=False,
        email_verified=True,
        role=UserRoleEnum.OPERATOR,
        permissions=json.dumps(permissions),
    )
    db.add(operator)
    await db.commit()
    await db.refresh(operator)
    return _operator_response(operator)


@router.get(
    "/parking-management",
    response_model=list[ParkingManagementResponse],
)
async def list_managed_parkings(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _ensure_parking_partner(db, current_user)
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
    return await ParkingManagementService.create_for_tenant(
        db,
        current_user.tenant_id,
        data,
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
    return await ParkingManagementService.update_for_tenant(
        db,
        current_user.tenant_id,
        parking_id,
        data,
    )


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
        role=user.role.value,
        permissions=_user_permissions(user),
        is_active=user.is_active,
        created_at=user.created_at.isoformat(),
    )


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
                    "status": "free",
                    "reservation": None,
                }
            )
            continue

        reservation, vehicle, customer = assigned
        status = "occupied" if reservation.status == "checked_in" else "pre_reserved"
        slots.append(_slot_payload(code, slot_type, status, reservation, vehicle, customer))

    return {
        "id": parking.id,
        "name": parking.name,
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
):
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
            "final_total": reservation.final_total,
            "selected_services": _reservation_services(reservation),
            "customer_name": customer.name if customer else "Cliente nao informado",
            "customer_phone": customer.phone if customer else None,
            "vehicle_plate": vehicle.plate if vehicle else None,
            "vehicle_label": f"{vehicle.brand} {vehicle.model}" if vehicle else None,
            "route_minutes": reservation.route_minutes,
            "created_at": reservation.created_at.isoformat(),
            "arrival_estimate_at": (
                reservation.arrival_estimate_at
                or reservation.created_at + timedelta(minutes=reservation.route_minutes)
            ).isoformat(),
            "is_manual_arrival": reservation.is_manual_arrival,
            "hold_expires_at": reservation.hold_expires_at.isoformat(),
            "cancelled_at": reservation.cancelled_at.isoformat()
            if reservation.cancelled_at
            else None,
            "cancellation_fee_amount": reservation.cancellation_fee_amount,
            "cancellation_credit_amount": reservation.cancellation_credit_amount,
        },
    }


def _slot_type(index: int, parking: ParkingManagementResponse) -> str:
    vip_limit = parking.vip_spots
    bus_limit = vip_limit + parking.bus_spots
    large_limit = bus_limit + parking.large_spots
    pickup_limit = large_limit + parking.pickup_spots

    if index <= vip_limit:
        return "vip"
    if index <= bus_limit:
        return "bus"
    if index <= large_limit:
        return "large"
    if index <= pickup_limit:
        return "pickup"
    if parking.covered_spots and index <= parking.covered_spots:
        return "covered"
    return "uncovered"


def _reservation_services(reservation: Reservation) -> list[dict]:
    if not reservation.selected_services_snapshot:
        return []

    try:
        services = json.loads(reservation.selected_services_snapshot)
    except json.JSONDecodeError:
        return []

    return services if isinstance(services, list) else []


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
