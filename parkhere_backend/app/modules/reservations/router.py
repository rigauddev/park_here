from datetime import datetime, timedelta
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.reservations.schemas import (
    CancelReservationRequest,
    PreCheckinReservationRequest,
    ReservationResponse,
)
from app.modules.reservations.service import ReservationService, _get_reservation_with_parking
from app.modules.users.models.user_model import User

router = APIRouter(prefix="/reservations", tags=["Reservations"])
PHOTO_ROOT = Path('/app/storage/inspection')


_PRIVATE_GUIDE_FIELDS = {"guide_user_id", "guide_commission_amount", "guide_platform_fee_amount", "guide_payout_amount"}


@router.post("/pre-checkin", response_model=ReservationResponse, response_model_exclude=_PRIVATE_GUIDE_FIELDS)
async def create_pre_checkin_reservation(
    data: PreCheckinReservationRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await ReservationService.create_pre_checkin(db, data, current_user)


@router.post("/{reservation_id}/checkin", response_model=ReservationResponse, response_model_exclude=_PRIVATE_GUIDE_FIELDS)
async def checkin_reservation(
    reservation_id: str,
    latitude: float | None = Query(default=None, ge=-90, le=90),
    longitude: float | None = Query(default=None, ge=-180, le=180),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await ReservationService.checkin(db, reservation_id, current_user, latitude, longitude)


@router.post("/{reservation_id}/photos")
async def upload_reservation_photo(
    reservation_id: str,
    kind: str,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    reservation, parking = await _get_reservation_with_parking(db, reservation_id)
    # Customers upload photos for their own reservation; staff uploads are
    # limited to the parking tenant.
    if current_user.role.value == 'customer':
        if reservation.user_id != current_user.id:
            raise HTTPException(status_code=403, detail='Reservation not allowed')
    elif current_user.tenant_id != parking.tenant_id:
        raise HTTPException(status_code=403, detail='Reservation not allowed')
    if kind not in {'front', 'rear', 'left', 'right'}:
        raise HTTPException(status_code=422, detail='Invalid photo kind')
    allowed_types = {None, 'image/jpeg', 'image/png', 'image/heic', 'image/heif', 'image/webp'}
    if file.content_type not in allowed_types:
        raise HTTPException(status_code=415, detail='Formato de imagem não suportado. Use JPG, PNG, HEIC ou WEBP.')
    payload = await file.read()
    if len(payload) > 30 * 1024 * 1024:
        raise HTTPException(status_code=413, detail='A foto deve ter no máximo 30 MB')
    PHOTO_ROOT.mkdir(parents=True, exist_ok=True)
    cutoff = datetime.utcnow() - timedelta(days=7)
    for old in PHOTO_ROOT.glob('*/*'):
        if old.is_file() and datetime.utcfromtimestamp(old.stat().st_mtime) < cutoff:
            old.unlink(missing_ok=True)
    folder = PHOTO_ROOT / reservation_id
    folder.mkdir(parents=True, exist_ok=True)
    extension = {'image/png': 'png', 'image/webp': 'webp', 'image/heic': 'heic', 'image/heif': 'heif'}.get(file.content_type or '', 'jpg')
    target = folder / f'{kind}.{extension}'
    target.write_bytes(payload)
    return {'reservation_id': reservation_id, 'kind': kind, 'retention_days': 7, 'content_type': file.content_type}


@router.post("/{reservation_id}/checkout", response_model=ReservationResponse, response_model_exclude=_PRIVATE_GUIDE_FIELDS)
async def checkout_reservation(
    reservation_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await ReservationService.checkout(db, reservation_id, current_user)


@router.post("/{reservation_id}/cancel", response_model=ReservationResponse, response_model_exclude=_PRIVATE_GUIDE_FIELDS)
async def cancel_reservation(
    reservation_id: str,
    data: CancelReservationRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await ReservationService.cancel(db, reservation_id, data, current_user)
