from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.reservations.schemas import (
    CancelReservationRequest,
    PreCheckinReservationRequest,
    ReservationResponse,
)
from app.modules.reservations.service import ReservationService
from app.modules.users.models.user_model import User

router = APIRouter(prefix="/reservations", tags=["Reservations"])


@router.post("/pre-checkin", response_model=ReservationResponse)
async def create_pre_checkin_reservation(
    data: PreCheckinReservationRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await ReservationService.create_pre_checkin(db, data, current_user)


@router.post("/{reservation_id}/checkin", response_model=ReservationResponse)
async def checkin_reservation(
    reservation_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await ReservationService.checkin(db, reservation_id, current_user)


@router.post("/{reservation_id}/checkout", response_model=ReservationResponse)
async def checkout_reservation(
    reservation_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await ReservationService.checkout(db, reservation_id, current_user)


@router.post("/{reservation_id}/cancel", response_model=ReservationResponse)
async def cancel_reservation(
    reservation_id: str,
    data: CancelReservationRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await ReservationService.cancel(db, reservation_id, data, current_user)
