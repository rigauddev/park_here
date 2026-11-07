import asyncio
import json
import os
from pathlib import Path
from uuid import uuid4
from datetime import datetime, timezone
from math import ceil
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException
from app.modules.users.models.user_model import User
from app.modules.users.models.user_model_role_enum import UserRoleEnum
from ..models import (
    RentalCompany, RentalVehicle, RentalReservation, RentalCheckin,
    RentalCheckout, RentalPlan, RentalMaintenance, RentalItem, RentalContract, RentalFine, RentalVehicleGroup,
)
from app.modules.parkings.models import Parking
from app.modules.partners.models import PartnerProfile
from app.modules.platform_fees.service import PlatformFeeService

class RentalService:
    DEFAULT_TERMS = (
        "O cliente declara que receberá o veículo nas condições registradas na vistoria, "
        "respeitará o período contratado, os limites de quilometragem e devolverá o veículo "
        "à locadora para a vistoria final."
    )

    @staticmethod
    async def list_groups(db: AsyncSession, company_id: str, current_user: User):
        company = await RentalService.company(db, company_id, current_user)
        result = await db.scalars(select(RentalVehicleGroup).where(
            RentalVehicleGroup.company_id == company.id,
            RentalVehicleGroup.is_active.is_(True),
        ).order_by(RentalVehicleGroup.is_default.desc(), RentalVehicleGroup.name))
        return result.all()

    @staticmethod
    async def set_group_blocked(db: AsyncSession, group_id: str, blocked: bool, current_user: User):
        if current_user.role not in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.SUPER_ADMIN}:
            raise HTTPException(status_code=403, detail="Somente o gestor pode bloquear categorias")
        group = await db.scalar(select(RentalVehicleGroup).where(RentalVehicleGroup.id == group_id))
        if group is None:
            raise HTTPException(status_code=404, detail="Categoria não encontrada")
        company = await RentalService.company(db, group.company_id, current_user)
        await RentalService.ensure_approved_partner(db, current_user)
        group.is_blocked = blocked
        await db.commit()
        await db.refresh(group)
        return group

    @staticmethod
    async def create_group(db: AsyncSession, data, current_user: User):
        company = await RentalService.company(db, data.company_id, current_user)
        if current_user.role not in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.SUPER_ADMIN} or company.tenant_id != current_user.tenant_id:
            raise HTTPException(status_code=403, detail='Sem permissão para cadastrar grupos de veículos')
        await RentalService.ensure_approved_partner(db, current_user)
        row = RentalVehicleGroup(**data.model_dump())
        db.add(row)
        await db.commit()
        await db.refresh(row)
        return row

    @staticmethod
    async def catalog_models(make: str, year: int, vehicle_type: str = 'car', model: str | None = None):
        """Consulta o catálogo público vPIC sem persistir dados externos automaticamente."""
        params = urlencode({'format': 'json'})
        path_type = 'car' if vehicle_type in {'car', 'suv', 'pickup', 'van', 'electric_car'} else 'motorcycle'
        url = f'https://vpic.nhtsa.dot.gov/api/vehicles/GetModelsForMakeYear/make/{quote(make)}/modelyear/{year}/vehicletype/{path_type}?{params}'

        def fetch():
            request = Request(url, headers={'User-Agent': 'ServiceHub/1.0'})
            with urlopen(request, timeout=8) as response:
                return json.loads(response.read().decode('utf-8'))

        try:
            payload = await asyncio.to_thread(fetch)
        except Exception as exc:
            raise HTTPException(status_code=502, detail=f'Catálogo de veículos indisponível: {exc}') from exc
        rows = payload.get('Results', [])
        if model:
            needle = model.casefold()
            rows = [row for row in rows if needle in str(row.get('Model_Name', '')).casefold()]
        image_urls = await RentalService._wikimedia_vehicle_images(make, model or (rows[0].get('Model_Name') if rows else ''), year)
        return [
            {
                'make': row.get('Make_Name'),
                'model': row.get('Model_Name'),
                'year': year,
                'vehicle_type': vehicle_type,
                'photo_urls': image_urls,
                'specifications': {'source': 'NHTSA vPIC'},
            }
            for row in rows[:50]
        ]

    @staticmethod
    async def _wikimedia_vehicle_images(make: str, model: str, year: int) -> list[str]:
        if not model:
            return []
        query = urlencode({
            'action': 'query', 'generator': 'search',
            'gsrsearch': f'{make} {model} car', 'gsrnamespace': '6',
            'gsrlimit': '4', 'prop': 'imageinfo',
            'iiprop': 'url|extmetadata', 'iiurlwidth': '640', 'format': 'json',
        })
        url = f'https://commons.wikimedia.org/w/api.php?{query}'

        def fetch():
            request = Request(url, headers={'User-Agent': 'ServiceHub/1.0 (vehicle catalog)'})
            with urlopen(request, timeout=8) as response:
                payload = json.loads(response.read().decode('utf-8'))
            pages = payload.get('query', {}).get('pages', {})
            return [
                info.get('thumburl') or info.get('url')
                for page in pages.values()
                for info in page.get('imageinfo', [])
                if info.get('thumburl') or info.get('url')
            ]

        try:
            return await asyncio.to_thread(fetch)
        except Exception:
            return []

    @staticmethod
    async def ensure_approved_partner(db: AsyncSession, current_user: User) -> None:
        if current_user.role == UserRoleEnum.SUPER_ADMIN:
            return
        # A partner may operate several service modules under the same tenant.
        # Rental approval is therefore valid when the tenant has an approved
        # profile and an active rental company, even if the original profile
        # was created as the parking matrix service.
        profile = await db.scalar(select(PartnerProfile).where(
            PartnerProfile.tenant_id == current_user.tenant_id,
            PartnerProfile.approval_status == 'approved',
        ).order_by(
            (PartnerProfile.service_type == 'vehicle_rental').desc(),
        ))
        company = await db.scalar(select(RentalCompany).where(
            RentalCompany.tenant_id == current_user.tenant_id,
            RentalCompany.is_active.is_(True),
        ))
        if profile is None or company is None:
            raise HTTPException(status_code=403, detail='A conta de locação ainda aguarda aprovação da plataforma')

    @staticmethod
    async def list_items(db: AsyncSession, company_id: str, current_user: User):
        company = await RentalService.company(db, company_id, current_user)
        result = await db.scalars(select(RentalItem).where(
            RentalItem.company_id == company.id, RentalItem.is_active.is_(True)
        ).order_by(RentalItem.name))
        return result.all()

    @staticmethod
    async def create_item(db: AsyncSession, data, current_user: User):
        company = await RentalService.company(db, data.company_id, current_user)
        if current_user.role not in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.SUPER_ADMIN} or company.tenant_id != current_user.tenant_id:
            raise HTTPException(status_code=403, detail="Sem permissão para cadastrar itens")
        await RentalService.ensure_approved_partner(db, current_user)
        row = RentalItem(**data.model_dump())
        db.add(row); await db.commit(); await db.refresh(row); return row

    @staticmethod
    async def get_contract(db: AsyncSession, reservation_id: str, current_user: User):
        reservation = await RentalService.get_reservation(db, reservation_id, current_user)
        contract = await db.scalar(select(RentalContract).where(RentalContract.reservation_id == reservation.id))
        if contract is None:
            contract = RentalContract(reservation_id=reservation.id, terms_text=RentalService.DEFAULT_TERMS)
            db.add(contract); await db.commit(); await db.refresh(contract)
        return contract

    @staticmethod
    async def accept_contract(db: AsyncSession, reservation_id: str, role: str, current_user: User):
        contract = await RentalService.get_contract(db, reservation_id, current_user)
        now = datetime.now(timezone.utc)
        if role == "customer":
            if current_user.role != UserRoleEnum.CUSTOMER:
                raise HTTPException(status_code=403, detail="Somente o cliente pode aceitar como cliente")
            contract.customer_accepted_at = now
        else:
            if current_user.role not in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.OPERATOR, UserRoleEnum.SUPER_ADMIN}:
                raise HTTPException(status_code=403, detail="Sem permissão para aceitar o contrato")
            contract.partner_accepted_at = now
        contract.status = "accepted" if contract.customer_accepted_at and contract.partner_accepted_at else "partially_accepted"
        await db.commit(); await db.refresh(contract); return contract

    @staticmethod
    async def list_fines(db: AsyncSession, current_user: User):
        stmt = select(RentalFine).order_by(RentalFine.occurred_at.desc())
        if current_user.role == UserRoleEnum.CUSTOMER:
            stmt = stmt.join(RentalReservation).where(RentalReservation.user_id == current_user.id)
        elif current_user.role != UserRoleEnum.SUPER_ADMIN:
            stmt = stmt.join(RentalReservation).where(RentalReservation.tenant_id == current_user.tenant_id)
        return (await db.scalars(stmt)).all()

    @staticmethod
    async def create_fine(db: AsyncSession, data, current_user: User):
        if current_user.role not in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.OPERATOR, UserRoleEnum.SUPER_ADMIN}:
            raise HTTPException(status_code=403, detail="Somente a equipe da locadora pode registrar multas")
        reservation = await RentalService.get_reservation(db, data.reservation_id, current_user)
        if reservation.vehicle_id != data.vehicle_id:
            raise HTTPException(status_code=422, detail="Veículo não pertence à reserva")
        row = RentalFine(**data.model_dump())
        db.add(row); await db.commit(); await db.refresh(row); return row

    @staticmethod
    async def list_plans(db: AsyncSession, company_id: str, current_user: User):
        company = await RentalService.company(db, company_id, current_user)
        result = await db.scalars(select(RentalPlan).where(
            RentalPlan.company_id == company.id,
            RentalPlan.is_active.is_(True),
        ).order_by(RentalPlan.name))
        return result.all()

    @staticmethod
    async def create_plan(db: AsyncSession, data, current_user: User):
        company = await RentalService.company(db, data.company_id, current_user)
        if current_user.role not in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.SUPER_ADMIN} or company.tenant_id != current_user.tenant_id:
            raise HTTPException(status_code=403, detail="Sem permissão para cadastrar planos")
        await RentalService.ensure_approved_partner(db, current_user)
        if data.group_id:
            group = await db.scalar(select(RentalVehicleGroup).where(RentalVehicleGroup.id == data.group_id, RentalVehicleGroup.company_id == company.id, RentalVehicleGroup.is_active.is_(True)))
            if group is None:
                raise HTTPException(status_code=422, detail='Grupo de veículos inválido para esta locadora')
        plan = RentalPlan(**data.model_dump())
        db.add(plan); await db.commit(); await db.refresh(plan); return plan

    @staticmethod
    async def list_maintenance(db: AsyncSession, vehicle_id: str, current_user: User):
        vehicle = await db.scalar(select(RentalVehicle).join(RentalCompany).where(
            RentalVehicle.id == vehicle_id, RentalCompany.is_active.is_(True)
        ))
        if vehicle is None:
            raise HTTPException(status_code=404, detail="Veículo da locadora não encontrado")
        await RentalService.company(db, vehicle.company_id, current_user)
        result = await db.scalars(select(RentalMaintenance).where(
            RentalMaintenance.vehicle_id == vehicle_id
        ).order_by(RentalMaintenance.performed_at.desc()))
        return result.all()

    @staticmethod
    async def create_maintenance(db: AsyncSession, data, current_user: User):
        vehicle = await db.scalar(select(RentalVehicle).join(RentalCompany).where(
            RentalVehicle.id == data.vehicle_id, RentalCompany.is_active.is_(True)
        ))
        if vehicle is None:
            raise HTTPException(status_code=404, detail="Veículo da locadora não encontrado")
        company = await RentalService.company(db, vehicle.company_id, current_user)
        if current_user.role not in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.SUPER_ADMIN} or company.tenant_id != current_user.tenant_id:
            raise HTTPException(status_code=403, detail="Sem permissão para registrar manutenção")
        await RentalService.ensure_approved_partner(db, current_user)
        row = RentalMaintenance(**data.model_dump())
        db.add(row); await db.commit(); await db.refresh(row); return row

    @staticmethod
    async def list_companies(db: AsyncSession, current_user: User):
        stmt = select(RentalCompany).where(RentalCompany.is_active.is_(True))
        if current_user.role not in {UserRoleEnum.CUSTOMER, UserRoleEnum.SUPER_ADMIN}:
            stmt = stmt.where(RentalCompany.tenant_id == current_user.tenant_id)
        return (await db.scalars(stmt.order_by(RentalCompany.name))).all()

    @staticmethod
    async def list_vehicles(db: AsyncSession, company_id: str, current_user: User):
        company = await RentalService.company(db, company_id, current_user)
        stmt = select(RentalVehicle).where(
            RentalVehicle.company_id == company.id,
            RentalVehicle.is_active.is_(True),
        )
        if current_user.role == UserRoleEnum.CUSTOMER:
            stmt = stmt.where(RentalVehicle.status == "available")
        result = await db.scalars(stmt.order_by(RentalVehicle.created_at.desc()))
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
        await RentalService.ensure_approved_partner(db, current_user)
        if data.parent_parking_id:
            parent = await db.scalar(select(Parking).where(
                Parking.id == data.parent_parking_id,
                Parking.tenant_id == current_user.tenant_id,
                Parking.is_active.is_(True),
            ))
            if parent is None:
                raise HTTPException(status_code=404, detail="Estacionamento matriz não encontrado")
        if data.parent_unit_id and not data.parent_service_type:
            raise HTTPException(status_code=422, detail="Informe o tipo do serviço matriz")
        company = RentalCompany(tenant_id=current_user.tenant_id, **data.model_dump())
        db.add(company); await db.commit(); await db.refresh(company); return company

    @staticmethod
    async def create_vehicle(db, data, current_user):
        company = await RentalService.company(db, data.company_id, current_user)
        if current_user.role not in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.SUPER_ADMIN} or company.tenant_id != current_user.tenant_id:
            raise HTTPException(status_code=403, detail="Sem permissão para cadastrar veículos")
        await RentalService.ensure_approved_partner(db, current_user)
        if data.group_id:
            group = await db.scalar(select(RentalVehicleGroup).where(RentalVehicleGroup.id == data.group_id, RentalVehicleGroup.company_id == company.id, RentalVehicleGroup.is_active.is_(True)))
            if group is None:
                raise HTTPException(status_code=422, detail='Grupo de veículos inválido para esta locadora')
        payload = data.model_dump()
        if payload.get('manufacture_year') is None:
            payload['manufacture_year'] = payload.get('year')
        vehicle = RentalVehicle(**payload); db.add(vehicle); await db.commit(); await db.refresh(vehicle); return vehicle

    @staticmethod
    async def update_vehicle(db, vehicle_id, data, current_user):
        vehicle = await db.scalar(select(RentalVehicle).where(RentalVehicle.id == vehicle_id, RentalVehicle.is_active.is_(True)))
        if vehicle is None:
            raise HTTPException(status_code=404, detail='Veículo não encontrado')
        company = await RentalService.company(db, vehicle.company_id, current_user)
        if current_user.role not in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.SUPER_ADMIN} or company.tenant_id != current_user.tenant_id:
            raise HTTPException(status_code=403, detail='Sem permissão para editar veículos')
        await RentalService.ensure_approved_partner(db, current_user)
        payload = data.model_dump(exclude_unset=True)
        if payload.get('group_id') is not None:
            group = await db.scalar(select(RentalVehicleGroup).where(
                RentalVehicleGroup.id == payload['group_id'], RentalVehicleGroup.company_id == company.id,
                RentalVehicleGroup.is_active.is_(True)))
            if group is None:
                raise HTTPException(status_code=422, detail='Grupo de veículos inválido para esta locadora')
        for key, value in payload.items():
            setattr(vehicle, key, value)
        if vehicle.manufacture_year is None:
            vehicle.manufacture_year = vehicle.year
        await db.commit(); await db.refresh(vehicle); return vehicle

    @staticmethod
    async def upload_crlv(db, vehicle_id, file, current_user):
        vehicle = await db.scalar(select(RentalVehicle).where(RentalVehicle.id == vehicle_id, RentalVehicle.is_active.is_(True)))
        if vehicle is None:
            raise HTTPException(status_code=404, detail='Veículo não encontrado')
        company = await RentalService.company(db, vehicle.company_id, current_user)
        allowed_staff = current_user.role in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.OPERATOR, UserRoleEnum.SUPER_ADMIN} and company.tenant_id == current_user.tenant_id
        allowed_customer = False
        if current_user.role == UserRoleEnum.CUSTOMER:
            allowed_customer = await db.scalar(select(RentalReservation.id).where(
                RentalReservation.vehicle_id == vehicle.id, RentalReservation.user_id == current_user.id
            )) is not None
        if not (allowed_staff or allowed_customer):
            raise HTTPException(status_code=403, detail='Sem permissão para acessar o documento do veículo')
        suffix = Path(file.filename or '').suffix.lower()
        allowed = {'.pdf': 'application/pdf', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png'}
        if suffix not in allowed or (file.content_type and file.content_type != allowed[suffix]):
            raise HTTPException(status_code=415, detail='O CRLV deve estar em PDF, JPG ou PNG')
        content = await file.read()
        if len(content) > 30 * 1024 * 1024:
            raise HTTPException(status_code=413, detail='O arquivo do CRLV deve ter no máximo 30 MB')
        folder = Path(os.getenv('RENTAL_DOCUMENTS_DIR', '/app/storage/rental_documents'))
        folder.mkdir(parents=True, exist_ok=True)
        name = f'{vehicle.id}-{uuid4().hex}{suffix}'
        path = folder / name
        path.write_bytes(content)
        vehicle.crlv_file_url = f'/rentals/vehicles/{vehicle.id}/documents/crlv'
        await db.commit(); await db.refresh(vehicle)
        return {'file_url': vehicle.crlv_file_url, 'file_name': file.filename}

    @staticmethod
    async def read_crlv(db, vehicle_id, current_user):
        vehicle = await db.scalar(select(RentalVehicle).where(RentalVehicle.id == vehicle_id, RentalVehicle.is_active.is_(True)))
        if vehicle is None or not vehicle.crlv_file_url:
            raise HTTPException(status_code=404, detail='CRLV não encontrado')
        company = await RentalService.company(db, vehicle.company_id, current_user)
        allowed_staff = current_user.role in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.OPERATOR, UserRoleEnum.SUPER_ADMIN} and company.tenant_id == current_user.tenant_id
        allowed_customer = current_user.role == UserRoleEnum.CUSTOMER and await db.scalar(select(RentalReservation.id).where(RentalReservation.vehicle_id == vehicle.id, RentalReservation.user_id == current_user.id)) is not None
        if not (allowed_staff or allowed_customer):
            raise HTTPException(status_code=403, detail='Sem permissão para acessar o documento do veículo')
        folder = Path(os.getenv('RENTAL_DOCUMENTS_DIR', '/app/storage/rental_documents'))
        files = list(folder.glob(f'{vehicle.id}-*'))
        if not files:
            raise HTTPException(status_code=404, detail='Arquivo do CRLV não encontrado')
        return files[0]

    @staticmethod
    async def upload_vehicle_photo(db, vehicle_id, file, current_user):
        vehicle = await db.scalar(select(RentalVehicle).where(RentalVehicle.id == vehicle_id, RentalVehicle.is_active.is_(True)))
        if vehicle is None:
            raise HTTPException(status_code=404, detail='Veículo não encontrado')
        company = await RentalService.company(db, vehicle.company_id, current_user)
        if current_user.role not in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.SUPER_ADMIN} or company.tenant_id != current_user.tenant_id:
            raise HTTPException(status_code=403, detail='Sem permissão para adicionar fotos')
        suffix = Path(file.filename or '').suffix.lower()
        if suffix not in {'.jpg', '.jpeg', '.png', '.webp'}:
            raise HTTPException(status_code=415, detail='A foto deve estar em JPG, PNG ou WEBP')
        content = await file.read()
        if len(content) > 30 * 1024 * 1024:
            raise HTTPException(status_code=413, detail='A foto deve ter no máximo 30 MB')
        folder = Path(os.getenv('RENTAL_DOCUMENTS_DIR', '/app/storage/rental_documents'))
        folder.mkdir(parents=True, exist_ok=True)
        name = f'{vehicle.id}-photo-{uuid4().hex}{suffix}'
        (folder / name).write_bytes(content)
        urls = list(vehicle.photo_urls or [])
        urls.append(f'/rentals/vehicles/{vehicle.id}/photos/{name}')
        vehicle.photo_urls = urls[:8]
        await db.commit(); await db.refresh(vehicle)
        return {'photo_url': urls[-1]}

    @staticmethod
    async def read_vehicle_photo(db, vehicle_id, name, current_user):
        vehicle = await db.scalar(select(RentalVehicle).where(RentalVehicle.id == vehicle_id, RentalVehicle.is_active.is_(True)))
        if vehicle is None:
            raise HTTPException(status_code=404, detail='Veículo não encontrado')
        company = await RentalService.company(db, vehicle.company_id, current_user)
        allowed_staff = current_user.role in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.OPERATOR, UserRoleEnum.SUPER_ADMIN} and company.tenant_id == current_user.tenant_id
        allowed_customer = current_user.role == UserRoleEnum.CUSTOMER and await db.scalar(select(RentalReservation.id).where(RentalReservation.vehicle_id == vehicle.id, RentalReservation.user_id == current_user.id)) is not None
        if not (allowed_staff or allowed_customer) or not any(str(item).endswith('/' + name) for item in (vehicle.photo_urls or [])):
            raise HTTPException(status_code=403, detail='Sem permissão para acessar esta foto')
        path = Path(os.getenv('RENTAL_DOCUMENTS_DIR', '/app/storage/rental_documents')) / name
        if not path.exists(): raise HTTPException(status_code=404, detail='Foto não encontrada')
        return path

    @staticmethod
    async def create_reservation(db, data, current_user):
        if current_user.role != UserRoleEnum.CUSTOMER:
            raise HTTPException(status_code=403, detail="Somente clientes podem reservar veículos")
        company = await RentalService.company(db, data.company_id, current_user)
        vehicle = await db.scalar(select(RentalVehicle).where(
            RentalVehicle.id == data.vehicle_id, RentalVehicle.company_id == company.id,
            RentalVehicle.status == "available", RentalVehicle.is_active.is_(True)).with_for_update())
        if vehicle is None: raise HTTPException(status_code=409, detail="Veículo indisponível")
        if vehicle.group_id and await db.scalar(select(RentalVehicleGroup.id).where(
            RentalVehicleGroup.id == vehicle.group_id,
            RentalVehicleGroup.is_blocked.is_(True),
        )):
            raise HTTPException(status_code=409, detail="A categoria deste veículo está bloqueada")
        plan = None
        if data.plan_id:
            plan = await db.scalar(select(RentalPlan).where(
                RentalPlan.id == data.plan_id,
                RentalPlan.company_id == company.id,
                RentalPlan.is_active.is_(True),
            ))
            if plan is None:
                raise HTTPException(status_code=404, detail="Plano de locação não encontrado")
            if plan.group_id and await db.scalar(select(RentalVehicleGroup.id).where(
                RentalVehicleGroup.id == plan.group_id,
                RentalVehicleGroup.is_blocked.is_(True),
            )):
                raise HTTPException(status_code=409, detail="A categoria deste veículo está bloqueada")
        days = max(1, ceil((data.end_date - data.start_date).total_seconds() / 86400))
        daily_price = plan.price_per_day if plan else vehicle.price_per_day
        base_amount = round(daily_price * days, 2)
        fee_lines = await PlatformFeeService.calculate_lines(
            db,
            {
                "vehicle_rental_customer": base_amount,
                "vehicle_rental_partner": base_amount,
            },
            company.tenant_id,
        )
        customer_fee = round(sum(
            line.fee_amount for line in fee_lines
            if line.service_type == "vehicle_rental_customer"
        ), 2)
        establishment_fee = round(sum(
            line.fee_amount for line in fee_lines
            if line.service_type == "vehicle_rental_partner"
        ), 2)
        platform_fee = round(customer_fee + establishment_fee, 2)
        final_total = round(base_amount + customer_fee, 2)
        reservation = RentalReservation(tenant_id=company.tenant_id, user_id=current_user.id,
            company_id=company.id, vehicle_id=vehicle.id, plan_id=data.plan_id,
            start_date=data.start_date, end_date=data.end_date,
            total_price=final_total, base_amount=base_amount,
            customer_fee_amount=customer_fee,
            establishment_fee_amount=establishment_fee,
            platform_fee_amount=platform_fee, final_total=final_total,
            platform_fee_snapshot=json.dumps([line.to_dict() for line in fee_lines]),
            status="pending", payment_status="pending", extras=json.dumps(data.extras or {}), km_start=data.km_start)
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
