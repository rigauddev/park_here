from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.modules.parkings.models import Parking
from app.modules.reservations.models import Reservation
from app.modules.reservations.schemas import (
    PreCheckinReservationRequest,
    ReservationResponse,
)

router = APIRouter(prefix="/reservations", tags=["Reservations"])


@router.post("/pre-checkin", response_model=ReservationResponse)
async def create_pre_checkin_reservation(
    data: PreCheckinReservationRequest,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Parking).where(Parking.id == data.parking_id))
    parking = result.scalar_one_or_none()

    if parking is None:
        raise HTTPException(status_code=404, detail="Parking not found")

    if parking.available_spots <= 0:
        raise HTTPException(status_code=409, detail="No available spots")

    parking.available_spots -= 1

    reservation = Reservation(
        parking_id=parking.id,
        vehicle_id=data.vehicle_id,
        route_minutes=data.route_minutes,
        hold_expires_at=datetime.utcnow() + timedelta(minutes=data.route_minutes),
        estimated_total=data.estimated_total,
    )

    db.add(reservation)
    await db.commit()
    await db.refresh(reservation)

    return _to_response(reservation)


def _to_response(reservation: Reservation) -> ReservationResponse:
    return ReservationResponse(
        id=reservation.id,
        parking_id=reservation.parking_id,
        status=reservation.status,
        route_minutes=reservation.route_minutes,
        hold_expires_at=reservation.hold_expires_at.isoformat(),
        estimated_total=reservation.estimated_total,
        payment_status=reservation.payment_status,
        notification_status=reservation.notification_status,
    )
