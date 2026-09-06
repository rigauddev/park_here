import json
from dataclasses import dataclass
from datetime import datetime, timedelta
from math import ceil

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.parkings.models import Parking, ParkingService
from app.modules.platform_fees.service import PlatformFeeService
from app.modules.reservations.models import Reservation
from app.modules.reservations.schemas import (
    CancelReservationRequest,
    PreCheckinReservationRequest,
    ReservationPlatformFeeSnapshot,
    ReservationResponse,
    ReservationServiceSnapshot,
)
from app.modules.customer_assets.models import Vehicle
from app.modules.users.models.user_model import User
from app.modules.users.models.user_model_role_enum import UserRoleEnum


@dataclass
class ReservationPricing:
    base_amount: float
    services_amount: float
    platform_fee_amount: float
    final_total: float
    services_snapshot: list[ReservationServiceSnapshot]
    platform_fee_snapshot: list[dict]


class ReservationService:
    VALID_SPOT_TYPES = {"uncovered", "covered", "vip", "large", "bus", "pickup"}
    VALID_PLANS = {"hourly", "daily", "weekly", "monthly"}
    FREE_CANCELLATION_MINUTES = 5
    CHECKOUT_GRACE_MINUTES = 15

    @staticmethod
    async def create_pre_checkin(
        db: AsyncSession,
        data: PreCheckinReservationRequest,
        current_user: User,
    ) -> ReservationResponse:
        parking = await _get_parking_with_services(db, data.parking_id)
        await _ensure_reservation_permission(db, data, current_user, parking)

        if parking.available_spots <= 0:
            raise HTTPException(status_code=409, detail="No available spots")

        if data.spot_code:
            await _ensure_spot_available(db, parking.id, data.spot_code)

        pricing = await _calculate_pricing(db, parking, data)
        parking.available_spots -= 1
        arrival_estimate_at = _arrival_estimate(data)

        reservation = Reservation(
            parking_id=parking.id,
            user_id=current_user.id,
            vehicle_id=data.vehicle_id,
            spot_code=data.spot_code,
            arrival_estimate_at=arrival_estimate_at,
            is_manual_arrival=data.is_manual_arrival,
            route_minutes=data.route_minutes,
            hold_expires_at=arrival_estimate_at,
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

    @staticmethod
    async def cancel(
        db: AsyncSession,
        reservation_id: str,
        data: CancelReservationRequest,
        current_user: User,
    ) -> ReservationResponse:
        reservation, parking = await _get_reservation_with_parking(db, reservation_id)
        _ensure_cancel_permission(current_user, reservation, parking)

        if reservation.status in {"cancelled", "completed", "checked_out"}:
            raise HTTPException(
                status_code=409,
                detail="Reservation cannot be cancelled",
            )

        if reservation.status == "checked_in" and current_user.role not in {
            UserRoleEnum.PARTNER_MANAGER,
            UserRoleEnum.PARKING_ADMIN,
        }:
            raise HTTPException(
                status_code=403,
                detail="Only partner administrator can cancel after check-in",
            )

        fee_amount = await _calculate_cancellation_fee(db, reservation)
        credit_amount = max((reservation.final_total or 0) - fee_amount, 0)

        reservation.status = "cancelled"
        reservation.cancelled_at = datetime.utcnow()
        reservation.cancelled_by_user_id = current_user.id
        reservation.cancellation_reason = data.reason
        reservation.cancellation_fee_amount = fee_amount
        reservation.cancellation_credit_amount = credit_amount
        if reservation.payment_status not in {"paid", "refunded"}:
            reservation.payment_status = "cancelled"

        parking.available_spots = min(parking.available_spots + 1, parking.total_spots)
        await db.commit()
        await db.refresh(reservation)
        return to_response(reservation)

    @staticmethod
    async def checkin(
        db: AsyncSession,
        reservation_id: str,
        current_user: User,
    ) -> ReservationResponse:
        reservation, parking = await _get_reservation_with_parking(db, reservation_id)
        _ensure_reservation_access(current_user, reservation, parking)

        staff_can_checkin_for_checkout_payment = current_user.role in {
            UserRoleEnum.PARTNER_MANAGER,
            UserRoleEnum.PARKING_ADMIN,
            UserRoleEnum.OPERATOR,
        } and reservation.payment_status in {"pending_checkin", "payment_pending"}

        if reservation.status not in {"pre_reserved", "confirmed"} or (
            reservation.payment_status != "paid"
            and not staff_can_checkin_for_checkout_payment
        ):
            raise HTTPException(
                status_code=409,
                detail="Reservation must be ready before check-in",
            )

        reservation.status = "checked_in"
        reservation.checked_in_at = datetime.utcnow()
        await db.commit()
        await db.refresh(reservation)
        return to_response(reservation)

    @staticmethod
    async def checkout(
        db: AsyncSession,
        reservation_id: str,
        current_user: User,
    ) -> ReservationResponse:
        reservation, parking = await _get_reservation_with_parking(db, reservation_id)
        _ensure_reservation_access(current_user, reservation, parking)

        if reservation.status != "checked_in":
            raise HTTPException(
                status_code=409,
                detail="Reservation must be checked in before checkout",
            )

        excess_minutes, excess_amount = calculate_checkout_excess(
            reservation,
            parking,
        )
        reservation.checkout_grace_minutes = ReservationService.CHECKOUT_GRACE_MINUTES
        reservation.checkout_excess_minutes = excess_minutes
        reservation.checkout_excess_amount = excess_amount
        if reservation.payment_status != "paid":
            reservation.payment_status = "checkout_payment_pending"
            await db.commit()
            raise HTTPException(
                status_code=402,
                detail={
                    "message": "Checkout blocked until payment is completed",
                    "checkout_excess_minutes": excess_minutes,
                    "checkout_excess_amount": excess_amount,
                    "checkout_grace_minutes": ReservationService.CHECKOUT_GRACE_MINUTES,
                    "amount_due": round((reservation.final_total or 0) + excess_amount, 2),
                },
            )

        if excess_amount > 0 and reservation.checkout_excess_paid_at is None:
            reservation.payment_status = "checkout_excess_pending"
            await db.commit()
            raise HTTPException(
                status_code=402,
                detail={
                    "message": "Checkout blocked until excess payment is completed",
                    "checkout_excess_minutes": excess_minutes,
                    "checkout_excess_amount": excess_amount,
                    "checkout_grace_minutes": ReservationService.CHECKOUT_GRACE_MINUTES,
                },
            )

        reservation.status = "completed"
        reservation.checked_out_at = datetime.utcnow()
        parking.available_spots = min(parking.available_spots + 1, parking.total_spots)
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


async def _get_reservation_with_parking(
    db: AsyncSession,
    reservation_id: str,
) -> tuple[Reservation, Parking]:
    result = await db.execute(
        select(Reservation, Parking)
        .join(Parking, Parking.id == Reservation.parking_id)
        .where(Reservation.id == reservation_id)
    )
    row = result.one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Reservation not found")
    return row[0], row[1]


async def _ensure_reservation_permission(
    db: AsyncSession,
    data: PreCheckinReservationRequest,
    current_user: User,
    parking: Parking,
) -> None:
    if current_user.role == UserRoleEnum.CUSTOMER:
        if not data.vehicle_id:
            raise HTTPException(
                status_code=422,
                detail="Vehicle is required to create a reservation",
            )

        result = await db.execute(
            select(Vehicle).where(
                Vehicle.id == data.vehicle_id,
                Vehicle.user_id == current_user.id,
            )
        )
        if result.scalar_one_or_none() is None:
            raise HTTPException(status_code=403, detail="Vehicle not allowed")
        return

    if current_user.role in {
        UserRoleEnum.PARTNER_MANAGER,
        UserRoleEnum.PARKING_ADMIN,
        UserRoleEnum.OPERATOR,
    }:
        if current_user.tenant_id != parking.tenant_id:
            raise HTTPException(status_code=403, detail="Parking not allowed")
        return

    raise HTTPException(status_code=403, detail="Insufficient permissions")


def _ensure_reservation_access(
    current_user: User,
    reservation: Reservation,
    parking: Parking,
) -> None:
    if current_user.role == UserRoleEnum.CUSTOMER:
        if reservation.user_id != current_user.id:
            raise HTTPException(status_code=403, detail="Reservation not allowed")
        return

    if current_user.role in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.PARKING_ADMIN}:
        if current_user.tenant_id != parking.tenant_id:
            raise HTTPException(status_code=403, detail="Reservation not allowed")
        return

    if current_user.role == UserRoleEnum.OPERATOR:
        if (
            current_user.tenant_id != parking.tenant_id
            or reservation.user_id != current_user.id
        ):
            raise HTTPException(status_code=403, detail="Reservation not allowed")
        return

    raise HTTPException(status_code=403, detail="Insufficient permissions")


def _ensure_cancel_permission(
    current_user: User,
    reservation: Reservation,
    parking: Parking,
) -> None:
    if current_user.role == UserRoleEnum.CUSTOMER:
        if reservation.user_id != current_user.id:
            raise HTTPException(status_code=403, detail="Reservation not allowed")
        return

    if current_user.role in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.PARKING_ADMIN}:
        if current_user.tenant_id != parking.tenant_id:
            raise HTTPException(status_code=403, detail="Reservation not allowed")
        return

    if current_user.role == UserRoleEnum.OPERATOR:
        if (
            current_user.tenant_id != parking.tenant_id
            or reservation.user_id != current_user.id
        ):
            raise HTTPException(status_code=403, detail="Reservation not allowed")
        if reservation.status == "checked_in":
            raise HTTPException(
                status_code=403,
                detail="Operator cannot cancel checked-in reservation",
            )
        return

    raise HTTPException(status_code=403, detail="Insufficient permissions")


async def _calculate_cancellation_fee(
    db: AsyncSession,
    reservation: Reservation,
) -> float:
    elapsed_minutes = (
        datetime.utcnow() - reservation.created_at.replace(tzinfo=None)
    ).total_seconds() / 60
    if elapsed_minutes <= ReservationService.FREE_CANCELLATION_MINUTES:
        return 0

    lines = await PlatformFeeService.calculate_lines(
        db,
        {"cancellation": reservation.final_total or reservation.estimated_total or 0},
    )
    return sum(line.fee_amount for line in lines)


def _arrival_estimate(data: PreCheckinReservationRequest) -> datetime:
    if data.arrival_estimate_at:
        try:
            return datetime.fromisoformat(
                data.arrival_estimate_at.replace("Z", "+00:00")
            ).replace(tzinfo=None)
        except ValueError as exc:
            raise HTTPException(
                status_code=422,
                detail="Invalid arrival estimate",
            ) from exc

    return datetime.utcnow() + timedelta(minutes=data.route_minutes)


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

    if data.spot_code is not None and not data.spot_code.strip():
        raise HTTPException(status_code=422, detail="Invalid spot code")

    if data.spot_type in {"covered", "vip"} and parking.covered_spots <= 0:
        raise HTTPException(status_code=422, detail="Covered area is not available")


async def _ensure_spot_available(
    db: AsyncSession,
    parking_id: str,
    spot_code: str,
) -> None:
    result = await db.execute(
        select(Reservation).where(
            Reservation.parking_id == parking_id,
            Reservation.spot_code == spot_code,
            Reservation.status.in_(["pre_reserved", "confirmed", "checked_in"]),
        )
    )
    if result.scalar_one_or_none() is not None:
        raise HTTPException(status_code=409, detail="Spot already reserved")


def _base_amount(
    parking: Parking,
    spot_type: str,
    pricing_plan: str,
    duration_hours: int,
) -> float:
    if spot_type in {"covered", "vip"}:
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


def calculate_checkout_excess(
    reservation: Reservation,
    parking: Parking,
) -> tuple[int, float]:
    if (
        reservation.pricing_plan != "hourly"
        or reservation.checked_in_at is None
        or reservation.duration_hours <= 0
    ):
        return 0, 0

    now = datetime.utcnow()
    checked_in_at = reservation.checked_in_at.replace(tzinfo=None)
    elapsed_minutes = max(int((now - checked_in_at).total_seconds() // 60), 0)
    included_minutes = (
        reservation.duration_hours * 60 + ReservationService.CHECKOUT_GRACE_MINUTES
    )
    excess_minutes = max(elapsed_minutes - included_minutes, 0)
    if excess_minutes == 0:
        return 0, 0

    additional_hour = _additional_hour_price(parking, reservation.spot_type)
    excess_amount = ceil(excess_minutes / 60) * additional_hour
    return excess_minutes, round(excess_amount, 2)


def _additional_hour_price(parking: Parking, spot_type: str) -> float:
    if spot_type in {"covered", "vip"}:
        return parking.covered_additional_hour_price or parking.additional_hour_price
    return parking.uncovered_additional_hour_price or parking.additional_hour_price


def _selected_services(
    services: list[ParkingService],
    requested_codes: list[str],
) -> list[ParkingService]:
    if not requested_codes:
        return []

    requested_codes = list(dict.fromkeys(requested_codes))
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
        checked_in_at=reservation.checked_in_at.isoformat()
        if reservation.checked_in_at
        else None,
        checked_out_at=reservation.checked_out_at.isoformat()
        if reservation.checked_out_at
        else None,
        spot_code=reservation.spot_code,
        arrival_estimate_at=(
            reservation.arrival_estimate_at.isoformat()
            if reservation.arrival_estimate_at
            else (
                reservation.created_at + timedelta(minutes=reservation.route_minutes)
            ).isoformat()
        ),
        is_manual_arrival=reservation.is_manual_arrival,
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
        cancelled_at=reservation.cancelled_at.isoformat()
        if reservation.cancelled_at
        else None,
        cancellation_fee_amount=reservation.cancellation_fee_amount,
        cancellation_credit_amount=reservation.cancellation_credit_amount,
        checkout_grace_minutes=reservation.checkout_grace_minutes,
        checkout_excess_minutes=reservation.checkout_excess_minutes,
        checkout_excess_amount=reservation.checkout_excess_amount,
        checkout_excess_paid_at=reservation.checkout_excess_paid_at.isoformat()
        if reservation.checkout_excess_paid_at
        else None,
    )
