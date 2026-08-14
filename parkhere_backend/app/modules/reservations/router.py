from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.modules.reservations.schemas import (
    PreCheckinReservationRequest,
    ReservationResponse,
)
from app.modules.reservations.service import ReservationService

router = APIRouter(prefix="/reservations", tags=["Reservations"])


@router.post("/pre-checkin", response_model=ReservationResponse)
async def create_pre_checkin_reservation(
    data: PreCheckinReservationRequest,
    db: AsyncSession = Depends(get_db),
):
    return await ReservationService.create_pre_checkin(db, data)
