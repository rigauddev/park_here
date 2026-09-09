from fastapi import APIRouter, Depends, Query
import unicodedata
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.modules.parkings.models import Parking
from app.modules.parkings.schemas import ParkingPricingResponse, ParkingResponse
from app.modules.partners.guide_models import GuideParkingLink
from app.modules.users.models.user_model import User

router = APIRouter(prefix="/parkings", tags=["Parkings"])


@router.get("", response_model=list[ParkingResponse])
async def list_parkings(
    city: str | None = Query(default=None, min_length=2),
    db: AsyncSession = Depends(get_db),
):
    query = (
        select(Parking)
        .options(selectinload(Parking.services))
        .where(Parking.is_active.is_(True))
    )
    result = await db.execute(
        query.order_by(Parking.rating.desc())
    )
    parkings = result.scalars().all()
    if city:
        normalized_city = _normalize_city(city)
        parkings = [
            parking
            for parking in parkings
            if normalized_city in _normalize_city(parking.city)
        ]
    return [_to_response(parking) for parking in parkings]


@router.get('/{parking_id}/guides')
async def list_affiliated_guides(parking_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(GuideParkingLink, User)
        .join(User, User.id == GuideParkingLink.guide_user_id)
        .where(GuideParkingLink.parking_id == parking_id, GuideParkingLink.status == 'approved')
    )
    return [
        {'id': guide.id, 'name': guide.name, 'email': guide.email}
        for _, guide in result.all()
    ]


def _normalize_city(value: str) -> str:
    return ''.join(
        char
        for char in unicodedata.normalize('NFKD', value.strip().lower())
        if not unicodedata.combining(char)
    )


_CANONICAL_CITIES = {
    'valenca': 'Valença',
    'sao paulo': 'São Paulo',
    'brasilia': 'Brasília',
    'goiania': 'Goiânia',
    'belem': 'Belém',
    'joao pessoa': 'João Pessoa',
    'florianopolis': 'Florianópolis',
}


def _canonical_city(value: str) -> str:
    return _CANONICAL_CITIES.get(_normalize_city(value), value)


def _to_response(parking: Parking) -> ParkingResponse:
    services = {service.code: service for service in parking.services if service.is_active}

    return ParkingResponse(
        id=parking.id,
        name=parking.name,
        city=_canonical_city(parking.city),
        lat=parking.lat,
        lng=parking.lng,
        rating=parking.rating,
        availableSpots=parking.available_spots,
        pricing=ParkingPricingResponse(
            firstHourPrice=parking.first_hour_price,
            additionalHourPrice=parking.additional_hour_price,
            dailyPrice=parking.daily_price,
            weeklyPrice=parking.weekly_price,
            monthlyPrice=parking.monthly_price,
            coveredDailyPrice=parking.covered_daily_price,
            uncoveredDailyPrice=parking.uncovered_daily_price,
            coveredFirstHourPrice=parking.covered_first_hour_price,
            uncoveredFirstHourPrice=parking.uncovered_first_hour_price,
        ),
        hasCarWash="car_wash" in services,
        hasTourGuide="tour_guide" in services,
        hasTransportService="transport" in services,
        hasCoveredArea=parking.has_covered_area,
        hasVipSpots=parking.has_vip_spots,
        coveredSpots=parking.covered_spots,
        uncoveredSpots=parking.uncovered_spots,
        vipSpots=parking.vip_spots,
        largeSpots=parking.large_spots,
        busSpots=parking.bus_spots,
        pickupSpots=parking.pickup_spots,
        motoHomeSpots=getattr(parking, 'moto_home_spots', 0),
        coveredDailyPrice=parking.covered_daily_price,
        uncoveredDailyPrice=parking.uncovered_daily_price,
        vipDailyPrice=parking.covered_daily_price,
        largeDailyPrice=parking.uncovered_daily_price,
        busDailyPrice=parking.uncovered_daily_price,
        pickupDailyPrice=parking.uncovered_daily_price,
        carWashPrice=services.get("car_wash").price if "car_wash" in services else 0,
        tourGuidePrice=services.get("tour_guide").price if "tour_guide" in services else 0,
        transportPrice=services.get("transport").price if "transport" in services else 0,
    )
