import json
from datetime import datetime, timezone
from math import ceil
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException
from app.modules.users.models.user_model import User
from app.modules.users.models.user_model_role_enum import UserRoleEnum
from ..models import RentalCompany, RentalVehicle, RentalReservation, RentalCheckin, RentalCheckout

class RentalService:
    @staticmethod
    async def list_companies(db: AsyncSession, current_user: User):
        stmt = select(RentalCompany).where(RentalCompany.is_active.is_(True))
        if current_user.role not in {UserRoleEnum.CUSTOMER, UserRoleEnum.SUPER_ADMIN}:
            stmt = stmt.where(RentalCompany.tenant_id == current_user.tenant_id)
        return (await db.scalars(stmt.order_by(RentalCompany.name))).all()

    @staticmethod
    async def list_vehicles(db: AsyncSession, company_id: str, current_user: User):
        company = await RentalService.company(db, company_id, current_user)
        result = await db.scalars(select(RentalVehicle).where(
            RentalVehicle.company_id == company.id, RentalVehicle.is_active.is_(True),
            RentalVehicle.status == "available"))
        return result.all()

    @staticmethod
    async def company(db, company_id, current_user):
        company = await db.scalar(select(RentalCompany).where(RentalCompany.id == company_id, RentalCompany.is_active.is_(True)))
        if company is None or (current_user.role not in {UserRoleEnum.CUSTOMER, UserRoleEnum.SUPER_ADMIN} and company.tenant_id != current_user.tenant_id):
            raise HTTPException(status_code=404, detail="Locadora não encontrada")
        return company

    @staticmethod
    async def create_company(db, data, current_user):
        if current_user.role not in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.SUPER_ADMIN}:
            raise HTTPException(status_code=403, detail="Somente o gestor do parceiro pode criar uma locadora")
        if not current_user.tenant_id:
            raise HTTPException(status_code=403, detail="Conta sem parceiro associado")
        company = RentalCompany(tenant_id=current_user.tenant_id, **data.model_dump())
        db.add(company); await db.commit(); await db.refresh(company); return company

    @staticmethod
    async def create_vehicle(db, data, current_user):
        company = await RentalService.company(db, data.company_id, current_user)
        if current_user.role not in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.SUPER_ADMIN} or company.tenant_id != current_user.tenant_id:
            raise HTTPException(status_code=403, detail="Sem permissão para cadastrar veículos")
        vehicle = RentalVehicle(**data.model_dump()); db.add(vehicle); await db.commit(); await db.refresh(vehicle); return vehicle

    @staticmethod
    async def create_reservation(db, data, current_user):
        if current_user.role != UserRoleEnum.CUSTOMER:
            raise HTTPException(status_code=403, detail="Somente clientes podem reservar veículos")
        company = await RentalService.company(db, data.company_id, current_user)
        vehicle = await db.scalar(select(RentalVehicle).where(
            RentalVehicle.id == data.vehicle_id, RentalVehicle.company_id == company.id,
            RentalVehicle.status == "available", RentalVehicle.is_active.is_(True)).with_for_update())
        if vehicle is None: raise HTTPException(status_code=409, detail="Veículo indisponível")
        days = max(1, ceil((data.end_date - data.start_date).total_seconds() / 86400))
        reservation = RentalReservation(tenant_id=company.tenant_id, user_id=current_user.id,
            company_id=company.id, vehicle_id=vehicle.id, start_date=data.start_date,
            end_date=data.end_date, total_price=round(vehicle.price_per_day * days, 2),
            status="pending", extras=json.dumps(data.extras or {}), km_start=data.km_start)
        vehicle.status = "reserved"; db.add(reservation); await db.commit(); await db.refresh(reservation); return reservation

    @staticmethod
    async def get_reservation(db, reservation_id, current_user):
        reservation = await db.scalar(select(RentalReservation).where(RentalReservation.id == reservation_id))
        if reservation is None or (current_user.role == UserRoleEnum.CUSTOMER and reservation.user_id != current_user.id) or (current_user.role != UserRoleEnum.CUSTOMER and reservation.tenant_id != current_user.tenant_id):
            raise HTTPException(status_code=404, detail="Reserva de locação não encontrada")
        return reservation

    @staticmethod
    async def list_reservations(db, current_user):
        stmt = select(RentalReservation).order_by(RentalReservation.created_at.desc())
        if current_user.role == UserRoleEnum.CUSTOMER:
            stmt = stmt.where(RentalReservation.user_id == current_user.id)
        elif current_user.role != UserRoleEnum.SUPER_ADMIN:
            stmt = stmt.where(RentalReservation.tenant_id == current_user.tenant_id)
        return (await db.scalars(stmt)).all()

    @staticmethod
    async def checkin(db, data, current_user):
        reservation = await RentalService.get_reservation(db, data.reservation_id, current_user)
        if reservation.status != "pending": raise HTTPException(status_code=409, detail="Reserva não está aguardando check-in")
        row = RentalCheckin(reservation_id=reservation.id, timestamp=datetime.now(timezone.utc), km=data.km, photos=data.photos, items=data.items, notes=data.notes)
        reservation.status = "checked_in"; reservation.km_start = data.km or reservation.km_start; db.add(row); await db.commit(); await db.refresh(row); return row

    @staticmethod
    async def checkout(db, data, current_user):
        reservation = await RentalService.get_reservation(db, data.reservation_id, current_user)
        if reservation.status != "checked_in": raise HTTPException(status_code=409, detail="Check-in da locação ainda não foi realizado")
        row = RentalCheckout(reservation_id=reservation.id, timestamp=datetime.now(timezone.utc), km=data.km, photos=data.photos, items=data.items, notes=data.notes, damage_fine=data.damage_fine)
        reservation.status = "completed"; reservation.km_end = data.km
        vehicle = await db.scalar(select(RentalVehicle).where(RentalVehicle.id == reservation.vehicle_id).with_for_update())
        if vehicle: vehicle.status = "available"
        db.add(row); await db.commit(); await db.refresh(row); return row
