from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.modules.parkings.models import Parking
from app.modules.parkings.schemas import ParkingPricingResponse, ParkingResponse

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
    if city:
        normalized_city = city.strip().lower()
        query = query.where(func.lower(Parking.city).contains(normalized_city))

    result = await db.execute(
        query.order_by(Parking.rating.desc())
    )

    return [_to_response(parking) for parking in result.scalars().all()]


def _to_response(parking: Parking) -> ParkingResponse:
    services = {service.code: service for service in parking.services if service.is_active}

    return ParkingResponse(
        id=parking.id,
        name=parking.name,
        city=parking.city,
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
        ),
        hasCarWash="car_wash" in services,
        hasTourGuide="tour_guide" in services,
        hasTransportService="transport" in services,
        hasCoveredArea=parking.has_covered_area,
        hasVipSpots=parking.has_vip_spots,
        carWashPrice=services.get("car_wash").price if "car_wash" in services else 0,
        tourGuidePrice=services.get("tour_guide").price if "tour_guide" in services else 0,
        transportPrice=services.get("transport").price if "transport" in services else 0,
    )
