import json
from dataclasses import dataclass
from datetime import datetime, timedelta

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.parkings.models import Parking, ParkingService
from app.modules.platform_fees.service import PlatformFeeService
from app.modules.reservations.models import Reservation
from app.modules.reservations.schemas import (
    PreCheckinReservationRequest,
    ReservationPlatformFeeSnapshot,
    ReservationResponse,
    ReservationServiceSnapshot,
)


@dataclass
class ReservationPricing:
    base_amount: float
    services_amount: float
    platform_fee_amount: float
    final_total: float
    services_snapshot: list[ReservationServiceSnapshot]
    platform_fee_snapshot: list[dict]


class ReservationService:
    VALID_SPOT_TYPES = {"uncovered", "covered"}
    VALID_PLANS = {"hourly", "daily", "weekly", "monthly"}

    @staticmethod
    async def create_pre_checkin(
        db: AsyncSession,
        data: PreCheckinReservationRequest,
    ) -> ReservationResponse:
        parking = await _get_parking_with_services(db, data.parking_id)

        if parking.available_spots <= 0:
            raise HTTPException(status_code=409, detail="No available spots")

        pricing = await _calculate_pricing(db, parking, data)
        parking.available_spots -= 1

        reservation = Reservation(
            parking_id=parking.id,
            vehicle_id=data.vehicle_id,
            route_minutes=data.route_minutes,
            hold_expires_at=datetime.utcnow() + timedelta(minutes=data.route_minutes),
            estimated_total=pricing.final_total,
            spot_type=data.spot_type,
            pricing_plan=data.pricing_plan,
            duration_hours=data.duration_hours,
            base_amount=pricing.base_amount,
            services_amount=pricing.services_amount,
            platform_fee_amount=pricing.platform_fee_amount,
            final_total=pricing.final_total,
            selected_services_snapshot=json.dumps(
                [service.model_dump() for service in pricing.services_snapshot]
            ),
            platform_fee_snapshot=json.dumps(pricing.platform_fee_snapshot),
        )

        db.add(reservation)
        await db.commit()
        await db.refresh(reservation)

        return to_response(reservation)


async def _get_parking_with_services(db: AsyncSession, parking_id: str) -> Parking:
    result = await db.execute(
        select(Parking)
        .options(selectinload(Parking.services))
        .where(Parking.id == parking_id, Parking.is_active.is_(True))
    )
    parking = result.scalar_one_or_none()
    if parking is None:
        raise HTTPException(status_code=404, detail="Parking not found")
    return parking


async def _calculate_pricing(
    db: AsyncSession,
    parking: Parking,
    data: PreCheckinReservationRequest,
) -> ReservationPricing:
    _validate_request(data, parking)

    base_amount = _base_amount(parking, data.spot_type, data.pricing_plan, data.duration_hours)
    selected_services = _selected_services(parking.services, data.service_codes)
    services_amount = sum(service.price for service in selected_services)
    service_amounts = {"parking": base_amount}
    for service in selected_services:
        service_amounts[service.code] = service_amounts.get(service.code, 0) + service.price

    platform_fee_lines = await PlatformFeeService.calculate_lines(db, service_amounts)
    platform_fee_amount = sum(line.fee_amount for line in platform_fee_lines)
    final_total = base_amount + services_amount + platform_fee_amount

    return ReservationPricing(
        base_amount=base_amount,
        services_amount=services_amount,
        platform_fee_amount=platform_fee_amount,
        final_total=final_total,
        services_snapshot=[
            ReservationServiceSnapshot(
                code=service.code,
                name=service.name,
                price=service.price,
            )
            for service in selected_services
        ],
        platform_fee_snapshot=[line.to_dict() for line in platform_fee_lines],
    )


def _validate_request(data: PreCheckinReservationRequest, parking: Parking) -> None:
    if data.spot_type not in ReservationService.VALID_SPOT_TYPES:
        raise HTTPException(status_code=422, detail="Invalid spot type")

    if data.pricing_plan not in ReservationService.VALID_PLANS:
        raise HTTPException(status_code=422, detail="Invalid pricing plan")

    if data.duration_hours <= 0:
        raise HTTPException(status_code=422, detail="Duration must be greater than zero")

    if data.route_minutes <= 0:
        raise HTTPException(status_code=422, detail="Route minutes must be greater than zero")

    if data.spot_type == "covered" and parking.covered_spots <= 0:
        raise HTTPException(status_code=422, detail="Covered area is not available")


def _base_amount(
    parking: Parking,
    spot_type: str,
    pricing_plan: str,
    duration_hours: int,
) -> float:
    if spot_type == "covered":
        first_hour = parking.covered_first_hour_price
        additional_hour = parking.covered_additional_hour_price
        daily = parking.covered_daily_price
        weekly = parking.covered_weekly_price
        monthly = parking.covered_monthly_price
    else:
        first_hour = parking.uncovered_first_hour_price or parking.first_hour_price
        additional_hour = (
            parking.uncovered_additional_hour_price or parking.additional_hour_price
        )
        daily = parking.uncovered_daily_price or parking.daily_price
        weekly = parking.uncovered_weekly_price or parking.weekly_price
        monthly = parking.uncovered_monthly_price or parking.monthly_price

    if pricing_plan == "hourly":
        return first_hour + max(duration_hours - 1, 0) * additional_hour
    if pricing_plan == "daily":
        return daily
    if pricing_plan == "weekly":
        return weekly
    return monthly


def _selected_services(
    services: list[ParkingService],
    requested_codes: list[str],
) -> list[ParkingService]:
    if not requested_codes:
        return []

    active_services = {service.code: service for service in services if service.is_active}
    missing = [code for code in requested_codes if code not in active_services]

    if missing:
        raise HTTPException(
            status_code=422,
            detail=f"Unavailable services: {', '.join(missing)}",
        )

    return [active_services[code] for code in requested_codes]


def to_response(reservation: Reservation) -> ReservationResponse:
    selected_services = []
    if reservation.selected_services_snapshot:
        selected_services = [
            ReservationServiceSnapshot(**service)
            for service in json.loads(reservation.selected_services_snapshot)
        ]
    platform_fees = []
    if reservation.platform_fee_snapshot:
        platform_fees = [
            ReservationPlatformFeeSnapshot(**fee)
            for fee in json.loads(reservation.platform_fee_snapshot)
        ]

    return ReservationResponse(
        id=reservation.id,
        parking_id=reservation.parking_id,
        status=reservation.status,
        route_minutes=reservation.route_minutes,
        hold_expires_at=reservation.hold_expires_at.isoformat(),
        estimated_total=reservation.estimated_total,
        spot_type=reservation.spot_type,
        pricing_plan=reservation.pricing_plan,
        duration_hours=reservation.duration_hours,
        base_amount=reservation.base_amount,
        services_amount=reservation.services_amount,
        platform_fee_amount=reservation.platform_fee_amount,
        final_total=reservation.final_total,
        selected_services=selected_services,
        platform_fees=platform_fees,
        payment_status=reservation.payment_status,
        notification_status=reservation.notification_status,
    )
