from fastapi import HTTPException
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.parkings.models import Parking, ParkingService
from app.modules.parkings.schemas import (
    ParkingAreaPricing,
    ParkingManagementRequest,
    ParkingManagementResponse,
    ParkingServiceInput,
    ParkingServiceResponse,
)


class ParkingManagementService:
    @staticmethod
    async def list_for_tenant(
        db: AsyncSession,
        tenant_id: str,
    ) -> list[ParkingManagementResponse]:
        result = await db.execute(
            select(Parking)
            .options(selectinload(Parking.services))
            .where(Parking.tenant_id == tenant_id)
            .order_by(Parking.created_at.desc())
        )
        return [_to_management_response(parking) for parking in result.scalars().all()]

    @staticmethod
    async def create_for_tenant(
        db: AsyncSession,
        tenant_id: str,
        data: ParkingManagementRequest,
    ) -> ParkingManagementResponse:
        _validate_capacity(data)

        uncovered = data.uncovered_pricing
        covered = data.covered_pricing or ParkingAreaPricing()

        parking = Parking(
            tenant_id=tenant_id,
            arrival_tolerance_minutes=data.arrival_tolerance_minutes,
            name=data.name,
            address=data.address,
            city=data.city,
            lat=data.lat,
            lng=data.lng,
            total_spots=data.total_spots,
            available_spots=data.available_spots
            if data.available_spots is not None
            else data.total_spots,
            covered_spots=data.covered_spots,
            uncovered_spots=data.uncovered_spots,
            vip_spots=data.vip_spots,
            large_spots=data.large_spots,
            bus_spots=data.bus_spots,
            pickup_spots=data.pickup_spots,
            first_hour_price=uncovered.first_hour_price,
            additional_hour_price=uncovered.additional_hour_price,
            daily_price=uncovered.daily_price,
            weekly_price=uncovered.weekly_price,
            monthly_price=uncovered.monthly_price,
            covered_first_hour_price=covered.first_hour_price,
            covered_additional_hour_price=covered.additional_hour_price,
            covered_daily_price=covered.daily_price,
            covered_weekly_price=covered.weekly_price,
            covered_monthly_price=covered.monthly_price,
            uncovered_first_hour_price=uncovered.first_hour_price,
            uncovered_additional_hour_price=uncovered.additional_hour_price,
            uncovered_daily_price=uncovered.daily_price,
            uncovered_weekly_price=uncovered.weekly_price,
            uncovered_monthly_price=uncovered.monthly_price,
            has_covered_area=data.covered_spots > 0,
            has_vip_spots=data.has_vip_spots or data.vip_spots > 0,
            has_24h_gate=data.has_24h_gate,
            has_security_system=data.has_security_system,
            wants_automatic_access=data.wants_automatic_access,
            has_automatic_access=data.has_automatic_access,
            is_active=data.is_active,
        )
        db.add(parking)
        await db.flush()

        _sync_services(parking.id, data.services, db)
        await db.commit()
        return await ParkingManagementService.get_for_tenant(
            db,
            tenant_id,
            parking.id,
        )

    @staticmethod
    async def update_for_tenant(
        db: AsyncSession,
        tenant_id: str,
        parking_id: str,
        data: ParkingManagementRequest,
    ) -> ParkingManagementResponse:
        _validate_capacity(data)
        parking = await _get_owned_parking(db, tenant_id, parking_id)

        uncovered = data.uncovered_pricing
        covered = data.covered_pricing or ParkingAreaPricing()

        parking.arrival_tolerance_minutes = data.arrival_tolerance_minutes
        parking.name = data.name
        parking.address = data.address
        parking.city = data.city
        parking.lat = data.lat
        parking.lng = data.lng
        parking.total_spots = data.total_spots
        if data.available_spots is None:
            parking.available_spots = min(parking.available_spots, data.total_spots)
        else:
            parking.available_spots = data.available_spots
        parking.covered_spots = data.covered_spots
        parking.uncovered_spots = data.uncovered_spots
        parking.vip_spots = data.vip_spots
        parking.large_spots = data.large_spots
        parking.bus_spots = data.bus_spots
        parking.pickup_spots = data.pickup_spots
        parking.first_hour_price = uncovered.first_hour_price
        parking.additional_hour_price = uncovered.additional_hour_price
        parking.daily_price = uncovered.daily_price
        parking.weekly_price = uncovered.weekly_price
        parking.monthly_price = uncovered.monthly_price
        parking.covered_first_hour_price = covered.first_hour_price
        parking.covered_additional_hour_price = covered.additional_hour_price
        parking.covered_daily_price = covered.daily_price
        parking.covered_weekly_price = covered.weekly_price
        parking.covered_monthly_price = covered.monthly_price
        parking.uncovered_first_hour_price = uncovered.first_hour_price
        parking.uncovered_additional_hour_price = uncovered.additional_hour_price
        parking.uncovered_daily_price = uncovered.daily_price
        parking.uncovered_weekly_price = uncovered.weekly_price
        parking.uncovered_monthly_price = uncovered.monthly_price
        parking.has_covered_area = data.covered_spots > 0
        parking.has_vip_spots = data.has_vip_spots or data.vip_spots > 0
        parking.has_24h_gate = data.has_24h_gate
        parking.has_security_system = data.has_security_system
        parking.wants_automatic_access = data.wants_automatic_access
        parking.has_automatic_access = data.has_automatic_access
        parking.is_active = data.is_active

        await db.execute(
            delete(ParkingService).where(ParkingService.parking_id == parking.id)
        )
        _sync_services(parking.id, data.services, db)
        await db.commit()
        return await ParkingManagementService.get_for_tenant(db, tenant_id, parking.id)

    @staticmethod
    async def get_for_tenant(
        db: AsyncSession,
        tenant_id: str,
        parking_id: str,
    ) -> ParkingManagementResponse:
        parking = await _get_owned_parking(db, tenant_id, parking_id)
        return _to_management_response(parking)


async def _get_owned_parking(
    db: AsyncSession,
    tenant_id: str,
    parking_id: str,
) -> Parking:
    result = await db.execute(
        select(Parking)
        .options(selectinload(Parking.services))
        .execution_options(populate_existing=True)
        .where(Parking.id == parking_id, Parking.tenant_id == tenant_id)
    )
    parking = result.scalar_one_or_none()
    if parking is None:
        raise HTTPException(status_code=404, detail="Parking not found")
    return parking


def _validate_capacity(data: ParkingManagementRequest) -> None:
    if data.total_spots <= 0:
        raise HTTPException(status_code=422, detail="Total spots must be greater than zero")

    if data.covered_spots < 0 or data.uncovered_spots < 0:
        raise HTTPException(status_code=422, detail="Spot quantities cannot be negative")

    if (
        data.vip_spots < 0
        or data.large_spots < 0
        or data.bus_spots < 0
        or data.pickup_spots < 0
    ):
        raise HTTPException(status_code=422, detail="Special spot quantities cannot be negative")

    if data.covered_spots + data.uncovered_spots != data.total_spots:
        raise HTTPException(
            status_code=422,
            detail="Covered plus uncovered spots must match total spots",
        )

    special_total = (
        data.vip_spots + data.large_spots + data.bus_spots + data.pickup_spots
    )
    if special_total > data.total_spots:
        raise HTTPException(
            status_code=422,
            detail="Special spot quantities cannot exceed total spots",
        )

    if data.available_spots is not None and (
        data.available_spots < 0 or data.available_spots > data.total_spots
    ):
        raise HTTPException(status_code=422, detail="Available spots must fit total spots")


def _sync_services(
    parking_id: str,
    services: list[ParkingServiceInput],
    db: AsyncSession,
) -> None:
    for service in services:
        db.add(
            ParkingService(
                parking_id=parking_id,
                code=service.code,
                name=service.name,
                price=service.price,
                is_active=service.is_active,
            )
        )


def _to_management_response(parking: Parking) -> ParkingManagementResponse:
    return ParkingManagementResponse(
        id=parking.id,
        arrival_tolerance_minutes=parking.arrival_tolerance_minutes,
        tenant_id=parking.tenant_id,
        name=parking.name,
        address=parking.address,
        city=parking.city,
        lat=parking.lat,
        lng=parking.lng,
        total_spots=parking.total_spots,
        available_spots=parking.available_spots,
        covered_spots=parking.covered_spots,
        uncovered_spots=parking.uncovered_spots,
        vip_spots=parking.vip_spots,
        large_spots=parking.large_spots,
        bus_spots=parking.bus_spots,
        pickup_spots=parking.pickup_spots,
        has_covered_area=parking.has_covered_area,
        has_vip_spots=parking.has_vip_spots,
        has_24h_gate=parking.has_24h_gate,
        has_security_system=parking.has_security_system,
        wants_automatic_access=parking.wants_automatic_access,
        has_automatic_access=parking.has_automatic_access,
        is_active=parking.is_active,
        uncovered_pricing=ParkingAreaPricing(
            first_hour_price=parking.uncovered_first_hour_price,
            additional_hour_price=parking.uncovered_additional_hour_price,
            daily_price=parking.uncovered_daily_price,
            weekly_price=parking.uncovered_weekly_price,
            monthly_price=parking.uncovered_monthly_price,
        ),
        covered_pricing=ParkingAreaPricing(
            first_hour_price=parking.covered_first_hour_price,
            additional_hour_price=parking.covered_additional_hour_price,
            daily_price=parking.covered_daily_price,
            weekly_price=parking.covered_weekly_price,
            monthly_price=parking.covered_monthly_price,
        ),
        services=[
            ParkingServiceResponse(
                id=service.id,
                code=service.code,
                name=service.name,
                price=service.price,
                is_active=service.is_active,
            )
            for service in parking.services
        ],
    )
