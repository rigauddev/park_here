from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.reservations.schemas import (
    CancelReservationRequest,
    ArrivalApprovalRequest,
    PreCheckinReservationRequest,
    ReservationResponse,
)
from app.modules.reservations.service import ReservationService, _get_reservation_with_parking, expire_user_reservations, to_response
from app.modules.reservations.models import Reservation
from app.modules.parkings.models import Parking
from app.modules.users.models.user_model import User

router = APIRouter(prefix="/reservations", tags=["Reservations"])
PHOTO_ROOT = Path('/app/storage/inspection')


_PRIVATE_GUIDE_FIELDS = {"guide_user_id", "guide_commission_amount", "guide_platform_fee_amount", "guide_payout_amount"}


@router.get("", response_model=list[ReservationResponse], response_model_exclude=_PRIVATE_GUIDE_FIELDS)
async def list_my_reservations(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return the customer's complete history, including expired reservations."""
    await expire_user_reservations(db, current_user.id)
    result = await db.execute(
        select(Reservation, User.name, Parking.name)
        .outerjoin(User, User.id == Reservation.cancelled_by_user_id)
        .join(Parking, Parking.id == Reservation.parking_id)
        .where(Reservation.user_id == current_user.id)
        .order_by(Reservation.created_at.desc())
    )
    rows = list(result.all())
    reservations = [row[0] for row in rows]
    for reservation, _, parking_name in rows:
        # The mobile client needs the display name without a second request.
        reservation.parking_name = parking_name
        # Include coordinates in the reservation payload for proximity-gated
        # hourly payments and map details.
        parking = await db.scalar(select(Parking).where(Parking.id == reservation.parking_id))
        if parking is not None:
            reservation.parking_lat = parking.lat
            reservation.parking_lng = parking.lng
            reservation.parking_city = parking.city
    actor_names = {reservation.id: name for reservation, name, _ in rows}
    return [
        to_response(reservation).model_copy(
            update={"cancelled_by_name": actor_names.get(reservation.id)}
        )
        for reservation in reservations
    ]


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
    if kind not in {'front', 'rear', 'left', 'right', 'spot_exit'}:
        raise HTTPException(status_code=422, detail='Invalid photo kind')
    allowed_types = {None, 'image/jpeg', 'image/png', 'image/heic', 'image/heif', 'image/webp'}
    if file.content_type not in allowed_types:
        raise HTTPException(status_code=415, detail='Formato de imagem não suportado. Use JPG, PNG, HEIC ou WEBP.')
    payload = await file.read()
    if len(payload) > 30 * 1024 * 1024:
        raise HTTPException(status_code=413, detail='A foto deve ter no máximo 30 MB')
    PHOTO_ROOT.mkdir(parents=True, exist_ok=True)
    cutoff = datetime.utcnow() - timedelta(days=30)
    for old in PHOTO_ROOT.glob('*/*'):
        if old.is_file() and datetime.utcfromtimestamp(old.stat().st_mtime) < cutoff:
            old.unlink(missing_ok=True)
    folder = PHOTO_ROOT / reservation_id
    folder.mkdir(parents=True, exist_ok=True)
    extension = {'image/png': 'png', 'image/webp': 'webp', 'image/heic': 'heic', 'image/heif': 'heif'}.get(file.content_type or '', 'jpg')
    target = folder / f'{kind}.{extension}'
    target.write_bytes(payload)
    return {'reservation_id': reservation_id, 'kind': kind, 'retention_days': 30, 'content_type': file.content_type}


@router.get("/{reservation_id}/photos")
async def list_reservation_photos(
    reservation_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List temporary inspection photos; files are retained for thirty days."""
    reservation, parking = await _get_reservation_with_parking(db, reservation_id)
    allowed = (
        reservation.user_id == current_user.id
        if current_user.role.value == 'customer'
        else current_user.tenant_id == parking.tenant_id
    )
    if not allowed:
        raise HTTPException(status_code=403, detail='Reservation not allowed')
    folder = PHOTO_ROOT / reservation_id
    cutoff = datetime.utcnow() - timedelta(days=30)
    photos = []
    if folder.exists():
        for path in sorted(folder.iterdir()):
            if not path.is_file():
                continue
            if datetime.utcfromtimestamp(path.stat().st_mtime) < cutoff:
                path.unlink(missing_ok=True)
                continue
            photos.append({
                'kind': path.stem,
                'filename': path.name,
                'content_type': f"image/{path.suffix.lstrip('.').lower()}",
                'retention_days': 30,
            })
    return {'reservation_id': reservation_id, 'photos': photos, 'retention_days': 30}


@router.post("/{reservation_id}/checkout", response_model=ReservationResponse, response_model_exclude=_PRIVATE_GUIDE_FIELDS)
async def checkout_reservation(
    reservation_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await ReservationService.checkout(db, reservation_id, current_user)


@router.post("/{reservation_id}/operator-checkout", response_model=ReservationResponse, response_model_exclude=_PRIVATE_GUIDE_FIELDS)
async def operator_checkout_reservation(
    reservation_id: str,
    reason: str = Form(...),
    photo: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Operator releases a checked-in vehicle after the customer leaves.

    The operator must attach one photo of the now-free spot. This explicit
    action replaces the former automatic hourly checkout.
    """
    if photo.content_type not in {None, 'image/jpeg', 'image/png', 'image/heic', 'image/heif', 'image/webp'}:
        raise HTTPException(status_code=415, detail='Formato de imagem não suportado.')
    payload = await photo.read()
    if len(payload) > 30 * 1024 * 1024:
        raise HTTPException(status_code=413, detail='A foto deve ter no máximo 30 MB')
    reservation, parking = await _get_reservation_with_parking(db, reservation_id)
    if current_user.role.value not in {'operator', 'partner_manager', 'parking_admin'} or current_user.tenant_id != parking.tenant_id:
        raise HTTPException(status_code=403, detail='Reservation not allowed')
    folder = PHOTO_ROOT / reservation_id
    folder.mkdir(parents=True, exist_ok=True)
    extension = {'image/png': 'png', 'image/webp': 'webp', 'image/heic': 'heic', 'image/heif': 'heif'}.get(photo.content_type or '', 'jpg')
    (folder / f'spot_exit.{extension}').write_bytes(payload)
    return await ReservationService.operator_checkout_without_customer(
        db, reservation_id, current_user, reason
    )


@router.post("/{reservation_id}/cancel", response_model=ReservationResponse, response_model_exclude=_PRIVATE_GUIDE_FIELDS)
async def cancel_reservation(
    reservation_id: str,
    data: CancelReservationRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await ReservationService.cancel(db, reservation_id, data, current_user)


@router.post("/{reservation_id}/arrival-approval", response_model=ReservationResponse, response_model_exclude=_PRIVATE_GUIDE_FIELDS)
async def approve_arrival(
    reservation_id: str,
    data: ArrivalApprovalRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await ReservationService.approve_arrival(
        db, reservation_id, data.decision, current_user
    )
