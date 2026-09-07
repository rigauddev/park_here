from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.customer_assets.models import Vehicle
from app.modules.reservations.models import Reservation
from app.modules.users.models.user_model import User

router = APIRouter(prefix="/customer-assets", tags=["Customer assets"])


class VehicleRequest(BaseModel):
    nickname: str
    plate: str
    brand: str
    model: str
    color: str
    vehicle_document: str
    ownership_type: str = "owner"
    is_active: bool = True


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
    }
