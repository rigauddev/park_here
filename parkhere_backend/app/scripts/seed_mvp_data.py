import asyncio

from sqlalchemy import select

from app.core.database import AsyncSessionLocal, engine
from app.core.security import hash_password
from app.db.base import Base
from app.modules.customer_assets.models import (
    DriverDocument,
    Vehicle,
    WalletPaymentMethod,
)
from app.modules.parkings.models import Parking, ParkingService
from app.modules.partners.models import PartnerProfile
from app.modules.reservations.models import Reservation
from app.modules.tenants.models.tenant_model_plan_enum import PlanEnum
from app.modules.tenants.models.tenant_model_status_enum import TenantStatusEnum
from app.modules.tenants.models.tenant_models import Tenant
from app.modules.users.models.user_model import User
from app.modules.users.models.user_model_role_enum import UserRoleEnum


async def seed():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as db:
        existing = await db.execute(select(User).where(User.email == "cliente@parkhere.test"))
        if existing.scalar_one_or_none():
            print("Seed already applied.")
            return

        tenant = Tenant(
            name="ParkHere Salvador Centro",
            cnpj="11222333000144",
            email="operacao@parkhere.test",
            plan=PlanEnum.PRO,
            status=TenantStatusEnum.TRIAL,
        )
        db.add(tenant)
        await db.flush()

        parking_admin = User(
            tenant_id=tenant.id,
            name="Admin",
            firt_name="ParkHere",
            email="admin@parkhere.test",
            password_hash=hash_password("123456"),
            phone="71999990000",
            phone_verified=True,
            email_verified=True,
            role=UserRoleEnum.PARKING_ADMIN,
        )
        customer = User(
            name="Cliente",
            firt_name="Teste",
            email="cliente@parkhere.test",
            password_hash=hash_password("123456"),
            phone="71988887777",
            phone_verified=True,
            email_verified=True,
            role=UserRoleEnum.CUSTOMER,
        )
        db.add_all([parking_admin, customer])
        await db.flush()

        parkings = [
            Parking(
                tenant_id=tenant.id,
                name="Estacionamento Central ParkHere",
                address="Av. Sete de Setembro, Salvador",
                lat=-12.9704,
                lng=-38.5124,
                rating=4.9,
                total_spots=60,
                available_spots=18,
                first_hour_price=10,
                additional_hour_price=5,
                daily_price=40,
                monthly_price=300,
                has_covered_area=True,
                has_vip_spots=True,
            ),
            Parking(
                tenant_id=tenant.id,
                name="ParkHere Pelourinho VIP",
                address="Rua Chile, Salvador",
                lat=-12.9712,
                lng=-38.5150,
                rating=4.7,
                total_spots=35,
                available_spots=7,
                first_hour_price=18,
                additional_hour_price=9,
                daily_price=75,
                monthly_price=560,
                has_covered_area=True,
                has_vip_spots=True,
            ),
            Parking(
                tenant_id=tenant.id,
                name="ParkHere Comercio Express",
                address="Av. Estados Unidos, Salvador",
                lat=-12.9688,
                lng=-38.5096,
                rating=4.4,
                total_spots=42,
                available_spots=11,
                first_hour_price=8,
                additional_hour_price=4,
                daily_price=32,
                monthly_price=240,
                has_covered_area=False,
                has_vip_spots=False,
            ),
        ]
        db.add_all(parkings)
        await db.flush()

        db.add_all(
            [
                ParkingService(parking_id=parkings[0].id, code="car_wash", name="Lava-jato", price=30),
                ParkingService(parking_id=parkings[0].id, code="tour_guide", name="Guia turistico", price=50),
                ParkingService(parking_id=parkings[1].id, code="car_wash", name="Lava-jato premium", price=50),
                ParkingService(parking_id=parkings[1].id, code="tour_guide", name="Guia turistico", price=100),
                ParkingService(parking_id=parkings[1].id, code="transport", name="Transporte", price=50),
                ParkingService(parking_id=parkings[2].id, code="transport", name="Transporte rapido", price=25),
            ]
        )

        vehicle = Vehicle(
            user_id=customer.id,
            nickname="Meu carro",
            plate="PKH1A23",
            brand="Toyota",
            model="Corolla",
            color="Prata",
            vehicle_document="CRLV-2026-TESTE",
            ownership_type="owner",
            is_active=True,
        )
        db.add(vehicle)
        await db.flush()

        db.add_all(
            [
                DriverDocument(
                    user_id=customer.id,
                    document_type="CNH",
                    document_number="CNH123456789",
                    is_verified=True,
                ),
                WalletPaymentMethod(
                    user_id=customer.id,
                    method_type="credit_card",
                    label="Visa final 4242",
                    last_four="4242",
                    is_active=True,
                ),
                WalletPaymentMethod(
                    user_id=customer.id,
                    method_type="pix",
                    label="Pix cliente@parkhere.test",
                    pix_key="cliente@parkhere.test",
                    is_active=False,
                ),
                Reservation(
                    parking_id=parkings[0].id,
                    user_id=customer.id,
                    vehicle_id=vehicle.id,
                    route_minutes=15,
                    hold_expires_at=__import__("datetime").datetime.utcnow()
                    + __import__("datetime").timedelta(minutes=15),
                    estimated_total=40,
                ),
            ]
        )

        await db.commit()

    print("Seed applied.")
    print("Customer login seed: cliente@parkhere.test / 123456")
    print("Parking admin seed: admin@parkhere.test / 123456")


if __name__ == "__main__":
    asyncio.run(seed())
