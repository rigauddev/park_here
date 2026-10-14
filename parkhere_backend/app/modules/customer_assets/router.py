from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.customer_assets.models import Vehicle, WalletPaymentMethod
from app.modules.reservations.models import Reservation
from app.modules.users.models.user_model import User
from app.modules.users.models.user_model_role_enum import UserRoleEnum

router = APIRouter(prefix="/customer-assets", tags=["Customer assets"])


class VehicleRequest(BaseModel):
    vehicle_type: str = Field(default="car", pattern=r"^(car|motorcycle|bicycle)$")
    nickname: str
    plate: str
    brand: str
    model: str
    color: str
    vehicle_document: str
    ownership_type: str = "owner"
    is_active: bool = True
    bicycle_parts: str | None = Field(default=None, max_length=500)


class SavedCardRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    method_type: str = Field(pattern=r"^(credit_card|debit_card)$")
    brand: str = Field(min_length=2, max_length=40)
    cardholder_name: str = Field(min_length=2, max_length=120)
    last_four: str = Field(pattern=r"^\d{4}$")
    expiration_month: int = Field(ge=1, le=12)
    expiration_year: int = Field(ge=2026, le=2099)
    is_default: bool = False

    @field_validator("cardholder_name")
    @classmethod
    def clean_cardholder(cls, value: str) -> str:
        cleaned = " ".join(value.split()).strip()
        if len(cleaned) < 2:
            raise ValueError("Cardholder name is required")
        return cleaned


def _require_customer(user: User) -> None:
    if user.role != UserRoleEnum.CUSTOMER:
        raise HTTPException(status_code=403, detail="Customer account required")


def _saved_card_payload(method: WalletPaymentMethod) -> dict:
    return {
        "id": method.id,
        "type": method.method_type,
        "label": method.label,
        "brand": method.card_brand,
        "holderName": method.cardholder_name,
        "lastFour": method.last_four,
        "expiry": (
            f"{method.expiration_month:02d}/{method.expiration_year % 100:02d}"
            if method.expiration_month and method.expiration_year
            else None
        ),
        "isActive": bool(method.is_active),
    }


@router.get("/payment-methods")
async def list_payment_methods(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_customer(current_user)
    result = await db.scalars(
        select(WalletPaymentMethod)
        .where(
            WalletPaymentMethod.user_id == current_user.id,
            WalletPaymentMethod.method_type.in_(["credit_card", "debit_card"]),
        )
        .order_by(WalletPaymentMethod.created_at.desc())
    )
    return [_saved_card_payload(item) for item in result.all()]


@router.post("/payment-methods", status_code=201)
async def save_payment_method(
    data: SavedCardRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_customer(current_user)
    if (data.expiration_year, data.expiration_month) < (datetime.utcnow().year, datetime.utcnow().month):
        raise HTTPException(status_code=422, detail="Card expiry date has passed")
    existing = await db.scalars(
        select(WalletPaymentMethod).where(WalletPaymentMethod.user_id == current_user.id)
    )
    methods = existing.all()
    make_default = data.is_default or not any(item.is_active for item in methods)
    if make_default:
        for item in methods:
            item.is_active = False
    method = WalletPaymentMethod(
        user_id=current_user.id,
        method_type=data.method_type,
        label=f"{data.brand} final {data.last_four}",
        last_four=data.last_four,
        card_brand=data.brand,
        cardholder_name=data.cardholder_name,
        expiration_month=data.expiration_month,
        expiration_year=data.expiration_year,
        pix_key=None,
        is_active=make_default,
    )
    db.add(method)
    await db.commit()
    await db.refresh(method)
    return _saved_card_payload(method)


@router.post("/payment-methods/{method_id}/default")
async def set_default_payment_method(
    method_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_customer(current_user)
    result = await db.scalars(
        select(WalletPaymentMethod).where(WalletPaymentMethod.user_id == current_user.id)
    )
    methods = result.all()
    target = next(
        (item for item in methods if item.id == method_id and item.method_type in {"credit_card", "debit_card"}),
        None,
    )
    if target is None:
        raise HTTPException(status_code=404, detail="Saved card not found")
    for item in methods:
        item.is_active = item.id == method_id
    await db.commit()
    await db.refresh(target)
    return _saved_card_payload(target)


@router.delete("/payment-methods/{method_id}", status_code=204)
async def delete_payment_method(
    method_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_customer(current_user)
    method = await db.scalar(
        select(WalletPaymentMethod).where(
            WalletPaymentMethod.id == method_id,
            WalletPaymentMethod.user_id == current_user.id,
            WalletPaymentMethod.method_type.in_(["credit_card", "debit_card"]),
        )
    )
    if method is None:
        raise HTTPException(status_code=404, detail="Saved card not found")
    await db.delete(method)
    await db.commit()
    return None


@router.get("/vehicles")
async def list_vehicles(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.scalars(select(Vehicle).where(Vehicle.user_id == current_user.id))
    return [_vehicle_payload(vehicle) for vehicle in result.all()]


@router.post("/vehicles", status_code=201)
async def create_vehicle(
    data: VehicleRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if data.is_active:
        vehicles = await db.scalars(select(Vehicle).where(Vehicle.user_id == current_user.id))
        for vehicle in vehicles.all():
            vehicle.is_active = False
    vehicle = Vehicle(user_id=current_user.id, **data.model_dump())
    db.add(vehicle)
    await db.commit()
    await db.refresh(vehicle)
    # Vincula reservas operacionais feitas com placa/telefone antes do cadastro.
    if current_user.phone:
        pending = await db.scalars(
            select(Reservation).where(
                Reservation.walk_in_plate == vehicle.plate,
                Reservation.walk_in_phone == current_user.phone,
                Reservation.user_id.is_(None),
                Reservation.status.in_(['pre_reserved', 'confirmed']),
            )
        )
        for reservation in pending.all():
            reservation.user_id = current_user.id
            reservation.vehicle_id = vehicle.id
        await db.commit()
    return _vehicle_payload(vehicle)


def _vehicle_payload(vehicle: Vehicle) -> dict:
    return {
        "id": vehicle.id,
        "nickname": vehicle.nickname,
        "plate": vehicle.plate,
        "brand": vehicle.brand,
        "model": vehicle.model,
        "color": vehicle.color,
        "documentFileName": vehicle.vehicle_document,
        "ownershipType": vehicle.ownership_type,
        "isActive": vehicle.is_active,
        "vehicleType": vehicle.vehicle_type,
        "bicycleParts": vehicle.bicycle_parts,
    }
