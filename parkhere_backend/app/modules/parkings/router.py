import json
from datetime import datetime
from zoneinfo import ZoneInfo
from fastapi import APIRouter, Depends, Query
import unicodedata
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.modules.parkings.models import Parking
from app.modules.parkings.schemas import ParkingPricingResponse, ParkingResponse
from app.modules.partners.guide_models import GuideParkingLink
from app.modules.partners.models import PartnerProfile
from app.modules.rentals.models import RentalCompany, RentalVehicle
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


@router.get("/cities")
async def list_service_cities(
    q: str | None = Query(default=None, min_length=1, max_length=120),
    db: AsyncSession = Depends(get_db),
):
    """Return distinct cities that currently have an active service.

    City lookup is deliberately data-driven: an unknown city returns an empty
    list and never becomes a client-side parsing error. The app can still
    accept arbitrary text and then display the no-results state.
    """
    parking_rows = await db.scalars(
        select(Parking.city).where(Parking.is_active.is_(True)).distinct()
    )
    rental_rows = await db.scalars(
        select(RentalCompany.city).where(RentalCompany.is_active.is_(True)).distinct()
    )
    partner_rows = await db.scalars(
        select(PartnerProfile.city)
        .where(PartnerProfile.approval_status == 'approved', PartnerProfile.city.is_not(None))
        .distinct()
    )
    normalized_query = _normalize_city(q) if q else ""
    values = []
    seen = set()
    values_to_scan = list(parking_rows.all()) + list(partner_rows.all())
    values_to_scan.extend(rental_rows.all())
    for value in values_to_scan:
        if not value:
            continue
        if normalized_query and normalized_query not in _normalize_city(value):
            continue
        canonical = _canonical_city(value)
        key = _normalize_city(canonical)
        if key not in seen:
            seen.add(key)
            values.append(canonical)
    return {"cities": values}


@router.get('/services/map')
async def list_map_services(
    city: str | None = Query(default=None, min_length=2),
    service_type: str | None = Query(default=None, max_length=40),
    db: AsyncSession = Depends(get_db),
):
    """Public discovery index used by the map.

    Each item is a service unit, not a second reservation contract. Parking
    keeps its existing detail flow; other service types are exposed so the map
    can filter and route to their own module pages.
    """
    normalized_city = _normalize_city(city) if city else ''
    allowed = {'parking', 'vehicle_rental', 'tour_guide'}
    requested = service_type if service_type in allowed else None
    items = []

    if requested in (None, 'parking'):
        parkings = (await db.scalars(select(Parking).where(Parking.is_active.is_(True)))).all()
        for parking in parkings:
            if normalized_city and normalized_city not in _normalize_city(parking.city):
                continue
            items.append({
                'id': parking.id, 'name': parking.name, 'city': _canonical_city(parking.city),
                'lat': parking.lat, 'lng': parking.lng, 'service_type': 'parking',
                'available_count': parking.available_spots, 'is_open': _is_open_now(parking),
            })

    if requested in (None, 'vehicle_rental'):
        companies = (await db.scalars(select(RentalCompany).where(RentalCompany.is_active.is_(True)))).all()
        for company in companies:
            company_city = company.city or ''
            if normalized_city and normalized_city not in _normalize_city(company_city):
                continue
            available = await db.scalar(
                select(func.count(RentalVehicle.id)).where(
                    RentalVehicle.company_id == company.id,
                    RentalVehicle.is_active.is_(True),
                    RentalVehicle.status == 'available',
                )
            )
            items.append({
                'id': company.id, 'name': company.name, 'city': company_city,
                'lat': company.latitude, 'lng': company.longitude,
                'service_type': 'vehicle_rental', 'available_count': int(available or 0),
                'is_open': True,
            })

    if requested in (None, 'tour_guide'):
        profiles = (await db.scalars(select(PartnerProfile).where(
            PartnerProfile.service_type == 'tour_guide',
            PartnerProfile.approval_status == 'approved',
        ))).all()
        for profile in profiles:
            profile_city = profile.city or ''
            if normalized_city and normalized_city not in _normalize_city(profile_city):
                continue
            if profile.latitude is None or profile.longitude is None:
                continue
            items.append({
                'id': profile.tenant_id, 'name': profile.company_name,
                'city': _canonical_city(profile_city), 'lat': profile.latitude,
                'lng': profile.longitude, 'service_type': 'tour_guide',
                'available_count': 1, 'is_open': True,
            })

    return {
        'city': _canonical_city(city) if city else None,
        'service_types': sorted({item['service_type'] for item in items}),
        'services': items,
    }


@router.get('/{parking_id}/guides')
async def list_affiliated_guides(parking_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(GuideParkingLink, User)
        .join(User, User.id == GuideParkingLink.guide_user_id)
        .join(Parking, Parking.id == GuideParkingLink.parking_id)
        .where(
            GuideParkingLink.parking_id == parking_id,
            GuideParkingLink.status == 'approved',
            Parking.accepts_guide_affiliates.is_(True),
            User.is_active.is_(True),
            User.tenant_id != Parking.tenant_id,
        )
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
    category_pricing = {
        key: _normalize_category_pricing(value)
        for key, value in json.loads(parking.category_pricing or '{}').items()
    }

    def category_price(category: str, key: str) -> float:
        return float(category_pricing.get(category, {}).get(key, 0) or 0)

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
        category_pricing=category_pricing,
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
        vipDailyPrice=category_price("vip", "daily_price"),
        largeDailyPrice=category_price("large", "daily_price"),
        busDailyPrice=category_price("bus", "daily_price"),
        pickupDailyPrice=category_price("pickup", "daily_price"),
        carWashPrice=services.get("car_wash").price if "car_wash" in services else 0,
        tourGuidePrice=services.get("tour_guide").price if "tour_guide" in services else 0,
        transportPrice=services.get("transport").price if "transport" in services else 0,
        isOpen=_is_open_now(parking),
        operating_hours=json.loads(parking.operating_hours or '{}'),
    )


def _is_open_now(parking: Parking) -> bool:
    raw = json.loads(parking.operating_hours or '{}')
    if not raw:
        return True
    keys = ('mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun')
    # Container clocks are commonly UTC; opening hours are configured in the
    # parking unit's local Brazil/Bahia time.
    now = datetime.now(ZoneInfo("America/Bahia"))
    hours = raw.get(keys[now.weekday()])
    if not hours or hours.get('closed') is True:
        return False
    opening, closing = hours.get('open'), hours.get('close')
    if not opening or not closing or opening == closing == '00:00':
        return False
    try:
        open_h, open_m = (int(part) for part in opening.split(':', 1))
        close_h, close_m = (int(part) for part in closing.split(':', 1))
        current = now.hour * 60 + now.minute
        start, end = open_h * 60 + open_m, close_h * 60 + close_m
        return current >= start or current < end if end < start else start <= current < end
    except (TypeError, ValueError):
        return True


def _normalize_category_pricing(value: dict) -> dict[str, float]:
    """Read current and pre-MVP seed formats into the stable public contract."""
    first_hour = value.get('first_hour_price', value.get('hourly', 0))
    return {
        'first_hour_price': float(first_hour or 0),
        'additional_hour_price': float(value.get('additional_hour_price', value.get('hourly', 0)) or 0),
        'daily_price': float(value.get('daily_price', value.get('daily', 0)) or 0),
        'weekly_price': float(value.get('weekly_price', value.get('weekly', 0)) or 0),
        'monthly_price': float(value.get('monthly_price', value.get('monthly', 0)) or 0),
    }
