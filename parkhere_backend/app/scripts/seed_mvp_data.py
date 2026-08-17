import asyncio
import json
from datetime import datetime, timedelta

from sqlalchemy import delete, select

from app.core.database import AsyncSessionLocal, engine
from app.core.security import hash_password
from app.db.base import Base
from app.modules.customer_assets.models import (
    DriverDocument,
    Vehicle,
    WalletPaymentMethod,
)
from app.modules.parkings.models import Parking, ParkingService
from app.modules.platform_fees.models import PlatformFee
from app.modules.partners.models import PartnerProfile
from app.modules.payments.models import PartnerPaymentAccount
from app.modules.reservations.models import Reservation
from app.modules.tenants.models.tenant_model_plan_enum import PlanEnum
from app.modules.tenants.models.tenant_model_status_enum import TenantStatusEnum
from app.modules.tenants.models.tenant_models import Tenant
from app.modules.users.models.user_model import User
from app.modules.users.models.user_model_role_enum import UserRoleEnum

DEFAULT_OPERATOR_PERMISSIONS = [
    "reservations.view",
    "parking_map.view",
    "reservations.create",
    "reservations.cancel_own",
    "checkin.own",
    "checkout.own",
    "payments.receive",
]
SEED_VEHICLE_ID = "00000000-0000-0000-0000-000000000001"


async def seed():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as db:
        existing = await db.execute(select(User).where(User.email == "cliente@parkhere.test"))
        if existing.scalar_one_or_none():
            await refresh_existing_seed(db)
            await ensure_system_admin_seed_user(db)
            await ensure_partner_seed_user(db)
            await ensure_partner_operator_seed_user(db)
            await cleanup_example_seed_users(db)
            await ensure_descriptive_seed_users(db)
            await ensure_partner_profile(db)
            await ensure_demo_partner_tenants(db)
            await ensure_platform_fees(db)
            await ensure_partner_payment_accounts(db)
            await ensure_customer_seed_assets(db)
            await ensure_seed_reservations(db)
            print("Seed already applied.")
            print("Seed partner, parking management fields, platform fees and payment account refreshed.")
            return

        tenant = Tenant(
            name="ParkHere Valenca Centro",
            cnpj="11222333000144",
            email="operacao@parkhere.test",
            plan=PlanEnum.PRO,
            status=TenantStatusEnum.TRIAL,
        )
        db.add(tenant)
        await db.flush()

        system_admin = User(
            tenant_id=None,
            name="Admin Master ParkHere",
            firt_name="Admin",
            email="admin@parkhere.test",
            password_hash=hash_password("123456"),
            phone="71999990000",
            phone_verified=True,
            email_verified=True,
            role=UserRoleEnum.SUPER_ADMIN,
        )
        partner_user = User(
            tenant_id=tenant.id,
            name="Parceiro Estacionamento",
            firt_name="Parceiro",
            email="parceiro@parkhere.test",
            password_hash=hash_password("123456"),
            phone="71999991111",
            phone_verified=True,
            email_verified=True,
            role=UserRoleEnum.PARTNER_MANAGER,
        )
        operator_user = User(
            tenant_id=tenant.id,
            name="Operador Estacionamento",
            firt_name="Operador",
            email="operador@parkhere.test",
            password_hash=hash_password("123456"),
            phone="71999993333",
            phone_verified=True,
            email_verified=True,
            role=UserRoleEnum.OPERATOR,
            permissions=json.dumps(DEFAULT_OPERATOR_PERMISSIONS),
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
        db.add_all([system_admin, partner_user, operator_user, customer])
        await db.flush()
        await ensure_partner_profile(db, tenant.id, commit=False)
        await ensure_descriptive_seed_users(db, commit=False)
        demo_tenants = await ensure_demo_partner_tenants(db, commit=False)

        parkings = [
            Parking(
                tenant_id=tenant.id,
                name="Estacionamento Central ParkHere",
                address="Rua Conselheiro Ferraz, Centro, Valenca - BA",
                city="Valenca",
                lat=-13.3703,
                lng=-39.0731,
                rating=4.9,
                total_spots=60,
                available_spots=18,
                covered_spots=24,
                uncovered_spots=36,
                first_hour_price=10,
                additional_hour_price=5,
                daily_price=40,
                weekly_price=180,
                monthly_price=300,
                covered_first_hour_price=14,
                covered_additional_hour_price=7,
                covered_daily_price=52,
                covered_weekly_price=230,
                covered_monthly_price=380,
                uncovered_first_hour_price=10,
                uncovered_additional_hour_price=5,
                uncovered_daily_price=40,
                uncovered_weekly_price=180,
                uncovered_monthly_price=300,
                has_covered_area=True,
                has_vip_spots=True,
                has_24h_gate=True,
                has_security_system=True,
                wants_automatic_access=True,
                has_automatic_access=False,
            ),
            Parking(
                tenant_id=demo_tenants["pelourinho"].id,
                name="ParkHere Valenca VIP",
                address="Av. ACM, Centro, Valenca - BA",
                city="Valenca",
                lat=-13.3668,
                lng=-39.0705,
                rating=4.7,
                total_spots=35,
                available_spots=7,
                covered_spots=20,
                uncovered_spots=15,
                first_hour_price=18,
                additional_hour_price=9,
                daily_price=75,
                weekly_price=330,
                monthly_price=560,
                covered_first_hour_price=22,
                covered_additional_hour_price=11,
                covered_daily_price=90,
                covered_weekly_price=390,
                covered_monthly_price=680,
                uncovered_first_hour_price=18,
                uncovered_additional_hour_price=9,
                uncovered_daily_price=75,
                uncovered_weekly_price=330,
                uncovered_monthly_price=560,
                has_covered_area=True,
                has_vip_spots=True,
                has_24h_gate=True,
                has_security_system=True,
                wants_automatic_access=True,
                has_automatic_access=False,
            ),
            Parking(
                tenant_id=demo_tenants["comercio"].id,
                name="ParkHere Valenca Comercio Express",
                address="Rua Governador Goncalves, Valenca - BA",
                city="Valenca",
                lat=-13.3727,
                lng=-39.0762,
                rating=4.4,
                total_spots=42,
                available_spots=11,
                covered_spots=0,
                uncovered_spots=42,
                first_hour_price=8,
                additional_hour_price=4,
                daily_price=32,
                weekly_price=150,
                monthly_price=240,
                covered_first_hour_price=0,
                covered_additional_hour_price=0,
                covered_daily_price=0,
                covered_weekly_price=0,
                covered_monthly_price=0,
                uncovered_first_hour_price=8,
                uncovered_additional_hour_price=4,
                uncovered_daily_price=32,
                uncovered_weekly_price=150,
                uncovered_monthly_price=240,
                has_covered_area=False,
                has_vip_spots=False,
                has_24h_gate=False,
                has_security_system=True,
                wants_automatic_access=False,
                has_automatic_access=False,
            ),
            Parking(
                tenant_id=demo_tenants["salvador"].id,
                name="ParkHere Salvador Barra",
                address="Av. Oceanica, Barra, Salvador - BA",
                city="Salvador",
                lat=-13.0091,
                lng=-38.5327,
                rating=4.6,
                total_spots=55,
                available_spots=16,
                covered_spots=20,
                uncovered_spots=35,
                first_hour_price=14,
                additional_hour_price=7,
                daily_price=58,
                weekly_price=260,
                monthly_price=440,
                covered_first_hour_price=18,
                covered_additional_hour_price=9,
                covered_daily_price=72,
                covered_weekly_price=320,
                covered_monthly_price=540,
                uncovered_first_hour_price=14,
                uncovered_additional_hour_price=7,
                uncovered_daily_price=58,
                uncovered_weekly_price=260,
                uncovered_monthly_price=440,
                has_covered_area=True,
                has_vip_spots=True,
                has_24h_gate=True,
                has_security_system=True,
                wants_automatic_access=False,
                has_automatic_access=False,
            ),
            Parking(
                tenant_id=demo_tenants["sao_paulo"].id,
                name="ParkHere Sao Paulo Paulista",
                address="Av. Paulista, Bela Vista, Sao Paulo - SP",
                city="Sao Paulo",
                lat=-23.5614,
                lng=-46.6559,
                rating=4.8,
                total_spots=120,
                available_spots=34,
                covered_spots=80,
                uncovered_spots=40,
                first_hour_price=22,
                additional_hour_price=12,
                daily_price=95,
                weekly_price=430,
                monthly_price=760,
                covered_first_hour_price=28,
                covered_additional_hour_price=14,
                covered_daily_price=115,
                covered_weekly_price=520,
                covered_monthly_price=920,
                uncovered_first_hour_price=22,
                uncovered_additional_hour_price=12,
                uncovered_daily_price=95,
                uncovered_weekly_price=430,
                uncovered_monthly_price=760,
                has_covered_area=True,
                has_vip_spots=True,
                has_24h_gate=True,
                has_security_system=True,
                wants_automatic_access=True,
                has_automatic_access=False,
            ),
            Parking(
                tenant_id=demo_tenants["curitiba"].id,
                name="ParkHere Curitiba Batel",
                address="Av. do Batel, Batel, Curitiba - PR",
                city="Curitiba",
                lat=-25.4421,
                lng=-49.2876,
                rating=4.7,
                total_spots=70,
                available_spots=22,
                covered_spots=45,
                uncovered_spots=25,
                first_hour_price=16,
                additional_hour_price=8,
                daily_price=65,
                weekly_price=290,
                monthly_price=510,
                covered_first_hour_price=20,
                covered_additional_hour_price=10,
                covered_daily_price=78,
                covered_weekly_price=350,
                covered_monthly_price=620,
                uncovered_first_hour_price=16,
                uncovered_additional_hour_price=8,
                uncovered_daily_price=65,
                uncovered_weekly_price=290,
                uncovered_monthly_price=510,
                has_covered_area=True,
                has_vip_spots=False,
                has_24h_gate=True,
                has_security_system=True,
                wants_automatic_access=False,
                has_automatic_access=False,
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
                ParkingService(parking_id=parkings[3].id, code="car_wash", name="Lavagem express", price=40),
                ParkingService(parking_id=parkings[3].id, code="tour_guide", name="Guia Barra", price=80),
                ParkingService(parking_id=parkings[4].id, code="car_wash", name="Lavagem premium", price=65),
                ParkingService(parking_id=parkings[4].id, code="transport", name="Transfer urbano", price=45),
                ParkingService(parking_id=parkings[5].id, code="car_wash", name="Lavagem ecológica", price=48),
                ParkingService(parking_id=parkings[5].id, code="transport", name="Transporte executivo", price=55),
            ]
        )

        vehicle = Vehicle(
            id=SEED_VEHICLE_ID,
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
                    hold_expires_at=datetime.utcnow() + timedelta(minutes=15),
                    estimated_total=40,
                    spot_type="uncovered",
                    pricing_plan="daily",
                    duration_hours=1,
                    base_amount=40,
                    services_amount=0,
                    platform_fee_amount=0,
                    final_total=40,
                    selected_services_snapshot="[]",
                ),
            ]
        )

        await ensure_platform_fees(db, commit=False)
        await ensure_partner_payment_accounts(db, tenant_id=tenant.id, commit=False)

        await db.commit()

    print("Seed applied.")
    print("Customer login seed: cliente@parkhere.test / 123456")
    print("Parking admin seed: admin@parkhere.test / 123456")
    print("Partner login seed: parceiro@parkhere.test / 123456")


async def refresh_existing_seed(db):
    main_tenant_result = await db.execute(
        select(Tenant).where(Tenant.cnpj == "11222333000144")
    )
    main_tenant = main_tenant_result.scalar_one_or_none()
    if main_tenant is not None:
        main_tenant.name = "ParkHere Valenca Centro"
        main_tenant.email = "operacao.valenca@parkhere.test"
    demo_tenants = await ensure_demo_partner_tenants(db, commit=False)

    parking_specs = {
        "Estacionamento Central ParkHere": {
            "tenant_id": main_tenant.id if main_tenant else None,
            "address": "Rua Conselheiro Ferraz, Centro, Valenca - BA",
            "city": "Valenca",
            "lat": -13.3703,
            "lng": -39.0731,
            "covered_spots": 24,
            "uncovered_spots": 36,
            "weekly_price": 180,
            "covered_first_hour_price": 14,
            "covered_additional_hour_price": 7,
            "covered_daily_price": 52,
            "covered_weekly_price": 230,
            "covered_monthly_price": 380,
            "uncovered_first_hour_price": 10,
            "uncovered_additional_hour_price": 5,
            "uncovered_daily_price": 40,
            "uncovered_weekly_price": 180,
            "uncovered_monthly_price": 300,
            "has_24h_gate": True,
            "has_security_system": True,
            "wants_automatic_access": True,
            "has_automatic_access": False,
        },
        "ParkHere Pelourinho VIP": {
            "name": "ParkHere Valenca VIP",
            "tenant_id": demo_tenants["pelourinho"].id,
            "address": "Av. ACM, Centro, Valenca - BA",
            "city": "Valenca",
            "lat": -13.3668,
            "lng": -39.0705,
            "covered_spots": 20,
            "uncovered_spots": 15,
            "weekly_price": 330,
            "covered_first_hour_price": 22,
            "covered_additional_hour_price": 11,
            "covered_daily_price": 90,
            "covered_weekly_price": 390,
            "covered_monthly_price": 680,
            "uncovered_first_hour_price": 18,
            "uncovered_additional_hour_price": 9,
            "uncovered_daily_price": 75,
            "uncovered_weekly_price": 330,
            "uncovered_monthly_price": 560,
            "has_24h_gate": True,
            "has_security_system": True,
            "wants_automatic_access": True,
            "has_automatic_access": False,
        },
        "ParkHere Comercio Express": {
            "name": "ParkHere Valenca Comercio Express",
            "tenant_id": demo_tenants["comercio"].id,
            "address": "Rua Governador Goncalves, Valenca - BA",
            "city": "Valenca",
            "lat": -13.3727,
            "lng": -39.0762,
            "covered_spots": 0,
            "uncovered_spots": 42,
            "weekly_price": 150,
            "covered_first_hour_price": 0,
            "covered_additional_hour_price": 0,
            "covered_daily_price": 0,
            "covered_weekly_price": 0,
            "covered_monthly_price": 0,
            "uncovered_first_hour_price": 8,
            "uncovered_additional_hour_price": 4,
            "uncovered_daily_price": 32,
            "uncovered_weekly_price": 150,
            "uncovered_monthly_price": 240,
            "has_24h_gate": False,
            "has_security_system": True,
            "wants_automatic_access": False,
            "has_automatic_access": False,
        },
        "ParkHere Salvador Barra": {
            "tenant_id": demo_tenants["salvador"].id,
            "address": "Av. Oceanica, Barra, Salvador - BA",
            "city": "Salvador",
            "lat": -13.0091,
            "lng": -38.5327,
            "rating": 4.6,
            "total_spots": 55,
            "available_spots": 16,
            "covered_spots": 20,
            "uncovered_spots": 35,
            "first_hour_price": 14,
            "additional_hour_price": 7,
            "daily_price": 58,
            "weekly_price": 260,
            "monthly_price": 440,
            "covered_first_hour_price": 18,
            "covered_additional_hour_price": 9,
            "covered_daily_price": 72,
            "covered_weekly_price": 320,
            "covered_monthly_price": 540,
            "uncovered_first_hour_price": 14,
            "uncovered_additional_hour_price": 7,
            "uncovered_daily_price": 58,
            "uncovered_weekly_price": 260,
            "uncovered_monthly_price": 440,
            "has_vip_spots": True,
            "has_24h_gate": True,
            "has_security_system": True,
            "wants_automatic_access": False,
            "has_automatic_access": False,
        },
        "ParkHere Sao Paulo Paulista": {
            "tenant_id": demo_tenants["sao_paulo"].id,
            "address": "Av. Paulista, Bela Vista, Sao Paulo - SP",
            "city": "Sao Paulo",
            "lat": -23.5614,
            "lng": -46.6559,
            "rating": 4.8,
            "total_spots": 120,
            "available_spots": 34,
            "covered_spots": 80,
            "uncovered_spots": 40,
            "first_hour_price": 22,
            "additional_hour_price": 12,
            "daily_price": 95,
            "weekly_price": 430,
            "monthly_price": 760,
            "covered_first_hour_price": 28,
            "covered_additional_hour_price": 14,
            "covered_daily_price": 115,
            "covered_weekly_price": 520,
            "covered_monthly_price": 920,
            "uncovered_first_hour_price": 22,
            "uncovered_additional_hour_price": 12,
            "uncovered_daily_price": 95,
            "uncovered_weekly_price": 430,
            "uncovered_monthly_price": 760,
            "has_vip_spots": True,
            "has_24h_gate": True,
            "has_security_system": True,
            "wants_automatic_access": True,
            "has_automatic_access": False,
        },
        "ParkHere Curitiba Batel": {
            "tenant_id": demo_tenants["curitiba"].id,
            "address": "Av. do Batel, Batel, Curitiba - PR",
            "city": "Curitiba",
            "lat": -25.4421,
            "lng": -49.2876,
            "rating": 4.7,
            "total_spots": 70,
            "available_spots": 22,
            "covered_spots": 45,
            "uncovered_spots": 25,
            "first_hour_price": 16,
            "additional_hour_price": 8,
            "daily_price": 65,
            "weekly_price": 290,
            "monthly_price": 510,
            "covered_first_hour_price": 20,
            "covered_additional_hour_price": 10,
            "covered_daily_price": 78,
            "covered_weekly_price": 350,
            "covered_monthly_price": 620,
            "uncovered_first_hour_price": 16,
            "uncovered_additional_hour_price": 8,
            "uncovered_daily_price": 65,
            "uncovered_weekly_price": 290,
            "uncovered_monthly_price": 510,
            "has_vip_spots": False,
            "has_24h_gate": True,
            "has_security_system": True,
            "wants_automatic_access": False,
            "has_automatic_access": False,
        },
    }
    parking_specs["ParkHere Valenca VIP"] = parking_specs["ParkHere Pelourinho VIP"]
    parking_specs["ParkHere Valenca Comercio Express"] = parking_specs[
        "ParkHere Comercio Express"
    ]

    result = await db.execute(select(Parking).where(Parking.name.in_(parking_specs.keys())))
    existing = {parking.name: parking for parking in result.scalars().all()}

    for parking_name, spec in parking_specs.items():
        if parking_name in {"ParkHere Pelourinho VIP", "ParkHere Comercio Express"}:
            continue

        parking = existing.get(parking_name)
        if parking is None:
            parking = Parking(name=parking_name, tenant_id=spec["tenant_id"])
            db.add(parking)

        for field, value in spec.items():
            if value is not None:
                setattr(parking, field, value)
        parking.has_covered_area = parking.covered_spots > 0

    for old_name in ["ParkHere Pelourinho VIP", "ParkHere Comercio Express"]:
        parking = existing.get(old_name)
        if parking is None:
            continue
        spec = parking_specs[old_name]
        for field, value in spec.items():
            if value is not None:
                setattr(parking, field, value)
        parking.has_covered_area = parking.covered_spots > 0

    await db.flush()
    await ensure_seed_parking_services(db, commit=False)

    await db.commit()


async def ensure_seed_parking_services(db, commit=True):
    service_specs = {
        "Estacionamento Central ParkHere": [
            {"code": "car_wash", "name": "Lava-jato", "price": 30},
            {"code": "tour_guide", "name": "Guia turistico", "price": 50},
        ],
        "ParkHere Valenca VIP": [
            {"code": "car_wash", "name": "Lava-jato premium", "price": 50},
            {"code": "tour_guide", "name": "Guia turistico", "price": 100},
            {"code": "transport", "name": "Transporte", "price": 50},
        ],
        "ParkHere Valenca Comercio Express": [
            {"code": "transport", "name": "Transporte rapido", "price": 25},
        ],
        "ParkHere Salvador Barra": [
            {"code": "car_wash", "name": "Lavagem express", "price": 40},
            {"code": "tour_guide", "name": "Guia Barra", "price": 80},
        ],
        "ParkHere Sao Paulo Paulista": [
            {"code": "car_wash", "name": "Lavagem premium", "price": 65},
            {"code": "transport", "name": "Transfer urbano", "price": 45},
        ],
        "ParkHere Curitiba Batel": [
            {"code": "car_wash", "name": "Lavagem ecologica", "price": 48},
            {"code": "transport", "name": "Transporte executivo", "price": 55},
        ],
    }

    result = await db.execute(
        select(Parking).where(Parking.name.in_(service_specs.keys()))
    )
    parkings = {parking.name: parking for parking in result.scalars().all()}

    for parking_name, services in service_specs.items():
        parking = parkings.get(parking_name)
        if parking is None:
            continue

        existing_result = await db.execute(
            select(ParkingService).where(ParkingService.parking_id == parking.id)
        )
        existing = {service.code: service for service in existing_result.scalars().all()}

        for spec in services:
            service = existing.get(spec["code"])
            if service is None:
                service = ParkingService(parking_id=parking.id, code=spec["code"])
                db.add(service)

            service.name = spec["name"]
            service.price = spec["price"]
            service.is_active = True

    if commit:
        await db.commit()


async def ensure_demo_partner_tenants(db, commit=True):
    specs = {
        "pelourinho": {
            "name": "Valenca Centro Parking Partners",
            "cnpj": "22333444000155",
            "email": "operacao.centro.valenca@parkhere.test",
            "profile_name": "ParkHere Valenca VIP",
            "user_email": "gestor.valenca.vip@parkhere.test",
            "operator_email": "operador.valenca.vip@parkhere.test",
        },
        "comercio": {
            "name": "Valenca Comercio Parking Partners",
            "cnpj": "33444555000166",
            "email": "operacao.comercio.valenca@parkhere.test",
            "profile_name": "ParkHere Valenca Comercio Express",
            "user_email": "gestor.valenca.comercio@parkhere.test",
            "operator_email": "operador.valenca.comercio@parkhere.test",
        },
        "salvador": {
            "name": "Salvador Barra Parking Partners",
            "cnpj": "44555666000177",
            "email": "operacao.barra.salvador@parkhere.test",
            "profile_name": "ParkHere Salvador Barra",
            "user_email": "gestor.salvador.barra@parkhere.test",
            "operator_email": "operador.salvador.barra@parkhere.test",
        },
        "sao_paulo": {
            "name": "Sao Paulo Paulista Parking Partners",
            "cnpj": "55666777000188",
            "email": "operacao.paulista.saopaulo@parkhere.test",
            "profile_name": "ParkHere Sao Paulo Paulista",
            "user_email": "gestor.saopaulo.paulista@parkhere.test",
            "operator_email": "operador.saopaulo.paulista@parkhere.test",
        },
        "curitiba": {
            "name": "Curitiba Batel Parking Partners",
            "cnpj": "66777888000199",
            "email": "operacao.batel.curitiba@parkhere.test",
            "profile_name": "ParkHere Curitiba Batel",
            "user_email": "gestor.curitiba.batel@parkhere.test",
            "operator_email": "operador.curitiba.batel@parkhere.test",
        },
    }
    tenants = {}

    for key, spec in specs.items():
        result = await db.execute(select(Tenant).where(Tenant.cnpj == spec["cnpj"]))
        tenant = result.scalar_one_or_none()
        if tenant is None:
            tenant = Tenant(
                name=spec["name"],
                cnpj=spec["cnpj"],
                email=spec["email"],
                plan=PlanEnum.PRO,
                status=TenantStatusEnum.TRIAL,
            )
            db.add(tenant)
            await db.flush()
        else:
            tenant.name = spec["name"]
            tenant.email = spec["email"]

        tenants[key] = tenant

        result = await db.execute(select(User).where(User.email == spec["user_email"]))
        user = result.scalar_one_or_none()
        if user is None:
            db.add(
                User(
                    tenant_id=tenant.id,
                    name=spec["profile_name"],
                    firt_name="Parceiro",
                    email=spec["user_email"],
                    password_hash=hash_password("123456"),
                    phone="71999992222",
                    phone_verified=True,
                    email_verified=True,
                    role=UserRoleEnum.PARTNER_MANAGER,
                )
            )
        else:
            user.tenant_id = tenant.id
            user.role = UserRoleEnum.PARTNER_MANAGER
            user.is_active = True

        result = await db.execute(
            select(PartnerProfile).where(PartnerProfile.tenant_id == tenant.id)
        )
        profile = result.scalar_one_or_none()
        if profile is None:
            db.add(
                PartnerProfile(
                    tenant_id=tenant.id,
                    service_type="parking",
                    company_name=spec["profile_name"],
                    cnpj=spec["cnpj"],
                    registration_status="active",
                    responsible_name=spec["profile_name"],
                    has_insurance=True,
                    insurance_provider="Seguro Parceiro Seed",
                    instagram="@parkhere.seed",
                    website="https://parkhere.test",
                    social_links="https://instagram.com/parkhere.seed",
                    approval_status="approved",
                )
            )
        else:
            profile.service_type = "parking"
            profile.company_name = spec["profile_name"]
            profile.approval_status = "approved"

        await ensure_partner_payment_accounts(db, tenant_id=tenant.id, commit=False)
        await _ensure_seed_user(
            db,
            tenant_id=tenant.id,
            email=spec["operator_email"],
            name=f"Operador {spec['profile_name']}",
            first_name="Operador",
            phone="71999996666",
            role=UserRoleEnum.OPERATOR,
            permissions=json.dumps(DEFAULT_OPERATOR_PERMISSIONS),
        )

    if commit:
        await db.commit()

    return tenants


async def ensure_partner_seed_user(db, commit=True):
    result = await db.execute(select(Tenant).where(Tenant.cnpj == "11222333000144"))
    tenant = result.scalar_one_or_none()
    if tenant is None:
        return

    result = await db.execute(select(User).where(User.email == "parceiro@parkhere.test"))
    user = result.scalar_one_or_none()
    if user is None:
        user = User(
            tenant_id=tenant.id,
            name="Parceiro Estacionamento",
            firt_name="Parceiro",
            email="parceiro@parkhere.test",
            password_hash=hash_password("123456"),
            phone="71999991111",
            phone_verified=True,
            email_verified=True,
            role=UserRoleEnum.PARTNER_MANAGER,
        )
        db.add(user)
    else:
        user.tenant_id = tenant.id
        user.role = UserRoleEnum.PARTNER_MANAGER
        user.phone_verified = True
        user.email_verified = True
        user.is_active = True

    if commit:
        await db.commit()


async def ensure_system_admin_seed_user(db, commit=True):
    result = await db.execute(select(User).where(User.email == "admin@parkhere.test"))
    user = result.scalar_one_or_none()
    if user is None:
        db.add(
            User(
                tenant_id=None,
                name="Admin Master ParkHere",
                firt_name="Admin",
                email="admin@parkhere.test",
                password_hash=hash_password("123456"),
                phone="71999990000",
                phone_verified=True,
                email_verified=True,
                role=UserRoleEnum.SUPER_ADMIN,
            )
        )
    else:
        user.tenant_id = None
        user.name = "Admin Master ParkHere"
        user.firt_name = "Admin"
        user.role = UserRoleEnum.SUPER_ADMIN
        user.phone_verified = True
        user.email_verified = True
        user.is_active = True

    if commit:
        await db.commit()


async def ensure_descriptive_seed_users(db, commit=True):
    result = await db.execute(select(Tenant).where(Tenant.cnpj == "11222333000144"))
    tenant = result.scalar_one_or_none()
    if tenant is None:
        return

    await _ensure_seed_user(
        db,
        tenant_id=tenant.id,
        email="gestor.central@parkhere-valenca.test",
        name="Gestor Central ParkHere",
        first_name="Gestor",
        phone="71999994444",
        role=UserRoleEnum.PARTNER_MANAGER,
    )
    await _ensure_seed_user(
        db,
        tenant_id=tenant.id,
        email="operador.central@parkhere-valenca.test",
        name="Operador Central ParkHere",
        first_name="Operador",
        phone="71999995555",
        role=UserRoleEnum.OPERATOR,
        permissions=json.dumps(DEFAULT_OPERATOR_PERMISSIONS),
    )

    if commit:
        await db.commit()


async def cleanup_example_seed_users(db, commit=True):
    await db.execute(
        delete(User).where(
            User.email.in_(
                [
                    "cliente.parceiro@estacionamento1.com",
                    "user.operador@estacionamento1.com",
                    "gestor.central@parkhere-salvador.test",
                    "operador.central@parkhere-salvador.test",
                ]
            )
        )
    )
    if commit:
        await db.commit()


async def _ensure_seed_user(
    db,
    *,
    tenant_id: str | None,
    email: str,
    name: str,
    first_name: str,
    phone: str,
    role: UserRoleEnum,
    permissions: str | None = None,
):
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if user is None:
        db.add(
            User(
                tenant_id=tenant_id,
                name=name,
                firt_name=first_name,
                email=email,
                password_hash=hash_password("123456"),
                phone=phone,
                phone_verified=True,
                email_verified=True,
                role=role,
                permissions=permissions,
            )
        )
        return

    user.tenant_id = tenant_id
    user.name = name
    user.firt_name = first_name
    user.phone = phone
    user.password_hash = hash_password("123456")
    user.phone_verified = True
    user.email_verified = True
    user.role = role
    user.permissions = permissions
    user.is_active = True


async def ensure_partner_operator_seed_user(db, commit=True):
    result = await db.execute(select(Tenant).where(Tenant.cnpj == "11222333000144"))
    tenant = result.scalar_one_or_none()
    if tenant is None:
        return

    result = await db.execute(select(User).where(User.email == "operador@parkhere.test"))
    user = result.scalar_one_or_none()
    if user is None:
        user = User(
            tenant_id=tenant.id,
            name="Operador Estacionamento",
            firt_name="Operador",
            email="operador@parkhere.test",
            password_hash=hash_password("123456"),
            phone="71999993333",
            phone_verified=True,
            email_verified=True,
            role=UserRoleEnum.OPERATOR,
            permissions=json.dumps(DEFAULT_OPERATOR_PERMISSIONS),
        )
        db.add(user)
    else:
        user.tenant_id = tenant.id
        user.role = UserRoleEnum.OPERATOR
        user.permissions = json.dumps(DEFAULT_OPERATOR_PERMISSIONS)
        user.phone_verified = True
        user.email_verified = True
        user.is_active = True

    if commit:
        await db.commit()


async def ensure_partner_profile(db, tenant_id=None, commit=True):
    if tenant_id is None:
        result = await db.execute(select(Tenant).where(Tenant.cnpj == "11222333000144"))
        tenant = result.scalar_one_or_none()
        if tenant is None:
            return
        tenant_id = tenant.id

    result = await db.execute(
        select(PartnerProfile).where(PartnerProfile.tenant_id == tenant_id)
    )
    profile = result.scalar_one_or_none()
    if profile is None:
        profile = PartnerProfile(
            tenant_id=tenant_id,
            service_type="parking",
            company_name="ParkHere Valenca Centro",
            cnpj="11222333000144",
            registration_status="active",
            responsible_name="Parceiro Estacionamento",
            has_insurance=True,
            insurance_provider="Seguro Parceiro Seed",
            instagram="@parkhere.seed",
            website="https://parkhere.test",
            social_links="https://instagram.com/parkhere.seed",
            approval_status="approved",
        )
        db.add(profile)
    else:
        profile.service_type = "parking"
        profile.company_name = "ParkHere Valenca Centro"
        profile.cnpj = "11222333000144"
        profile.registration_status = "active"
        profile.responsible_name = "Parceiro Estacionamento"
        profile.has_insurance = True
        profile.insurance_provider = "Seguro Parceiro Seed"
        profile.instagram = "@parkhere.seed"
        profile.website = "https://parkhere.test"
        profile.social_links = "https://instagram.com/parkhere.seed"
        profile.approval_status = "approved"

    if commit:
        await db.commit()


async def ensure_customer_seed_assets(db, commit=True):
    result = await db.execute(select(User).where(User.email == "cliente@parkhere.test"))
    customer = result.scalar_one_or_none()
    if customer is None:
        return

    result = await db.execute(select(Vehicle).where(Vehicle.id == SEED_VEHICLE_ID))
    vehicle = result.scalar_one_or_none()
    if vehicle is None:
        db.add(
            Vehicle(
                id=SEED_VEHICLE_ID,
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
        )
    else:
        vehicle.user_id = customer.id
        vehicle.is_active = True
        vehicle.brand = "Toyota"
        vehicle.model = "Corolla"

    document_result = await db.execute(
        select(DriverDocument).where(DriverDocument.user_id == customer.id)
    )
    if document_result.scalar_one_or_none() is None:
        db.add(
            DriverDocument(
                user_id=customer.id,
                document_type="CNH",
                document_number="CNH123456789",
                is_verified=True,
            )
        )

    card_result = await db.execute(
        select(WalletPaymentMethod).where(
            WalletPaymentMethod.user_id == customer.id,
            WalletPaymentMethod.method_type == "credit_card",
        )
    )
    if card_result.scalar_one_or_none() is None:
        db.add(
            WalletPaymentMethod(
                user_id=customer.id,
                method_type="credit_card",
                label="Visa final 4242",
                last_four="4242",
                is_active=True,
            )
        )

    pix_result = await db.execute(
        select(WalletPaymentMethod).where(
            WalletPaymentMethod.user_id == customer.id,
            WalletPaymentMethod.method_type == "pix",
        )
    )
    if pix_result.scalar_one_or_none() is None:
        db.add(
            WalletPaymentMethod(
                user_id=customer.id,
                method_type="pix",
                label="Pix cliente@parkhere.test",
                pix_key="cliente@parkhere.test",
                is_active=False,
            )
        )

    if commit:
        await db.commit()


async def ensure_seed_reservations(db, commit=True):
    customer_result = await db.execute(
        select(User).where(User.email == "cliente@parkhere.test")
    )
    customer = customer_result.scalar_one_or_none()
    parking_result = await db.execute(
        select(Parking).where(Parking.name == "Estacionamento Central ParkHere")
    )
    parking = parking_result.scalar_one_or_none()
    if customer is None or parking is None:
        return

    service_snapshot = json.dumps(
        [{"code": "car_wash", "name": "Lava-jato", "price": 30.0}]
    )
    scenarios = [
        {
            "marker": "seed_pre_reserved_pending",
            "status": "pre_reserved",
            "payment_status": "pending_checkin",
            "pricing_plan": "hourly",
            "duration_hours": 1,
            "base_amount": 10,
            "services_amount": 0,
            "platform_fee_amount": 2,
            "final_total": 12,
            "checked_in_at": None,
            "checked_out_at": None,
            "services": "[]",
            "spot_code": "V003",
            "spot_type": "uncovered",
            "route_minutes": 18,
            "is_manual_arrival": False,
        },
        {
            "marker": "seed_confirmed_paid_with_service",
            "status": "confirmed",
            "payment_status": "paid",
            "pricing_plan": "daily",
            "duration_hours": 1,
            "base_amount": 40,
            "services_amount": 30,
            "platform_fee_amount": 5.5,
            "final_total": 75.5,
            "checked_in_at": None,
            "checked_out_at": None,
            "services": service_snapshot,
            "spot_code": "V004",
            "spot_type": "covered",
            "route_minutes": 1,
            "is_manual_arrival": True,
        },
        {
            "marker": "seed_checked_in_pending_checkout_payment",
            "status": "checked_in",
            "payment_status": "pending_checkin",
            "pricing_plan": "hourly",
            "duration_hours": 2,
            "base_amount": 15,
            "services_amount": 0,
            "platform_fee_amount": 2.25,
            "final_total": 17.25,
            "checked_in_at": datetime.utcnow() - timedelta(hours=1),
            "checked_out_at": None,
            "services": "[]",
            "spot_code": "V005",
            "spot_type": "large",
            "route_minutes": 1,
            "is_manual_arrival": True,
        },
        {
            "marker": "seed_checked_in_paid",
            "status": "checked_in",
            "payment_status": "paid",
            "pricing_plan": "hourly",
            "duration_hours": 3,
            "base_amount": 20,
            "services_amount": 0,
            "platform_fee_amount": 2.5,
            "final_total": 22.5,
            "checked_in_at": datetime.utcnow() - timedelta(hours=2),
            "checked_out_at": None,
            "services": "[]",
            "spot_code": "V006",
            "spot_type": "vip",
            "route_minutes": 1,
            "is_manual_arrival": True,
        },
        {
            "marker": "seed_completed_paid",
            "status": "completed",
            "payment_status": "paid",
            "pricing_plan": "daily",
            "duration_hours": 1,
            "base_amount": 40,
            "services_amount": 0,
            "platform_fee_amount": 3.5,
            "final_total": 43.5,
            "checked_in_at": datetime.utcnow() - timedelta(hours=4),
            "checked_out_at": datetime.utcnow() - timedelta(hours=1),
            "services": "[]",
            "spot_code": "V007",
            "spot_type": "pickup",
            "route_minutes": 1,
            "is_manual_arrival": True,
        },
    ]

    for scenario in scenarios:
        existing_result = await db.execute(
            select(Reservation).where(
                Reservation.parking_id == parking.id,
                Reservation.notification_status == scenario["marker"],
            )
        )
        reservation = existing_result.scalar_one_or_none()
        if reservation is None:
            reservation = Reservation(
                parking_id=parking.id,
                user_id=customer.id,
                vehicle_id=SEED_VEHICLE_ID,
                notification_status=scenario["marker"],
            )
            db.add(reservation)

        reservation.route_minutes = scenario["route_minutes"]
        reservation.arrival_estimate_at = datetime.utcnow() + timedelta(
            minutes=scenario["route_minutes"]
        )
        reservation.hold_expires_at = reservation.arrival_estimate_at
        reservation.estimated_total = scenario["final_total"]
        reservation.spot_code = scenario["spot_code"]
        reservation.spot_type = scenario["spot_type"]
        reservation.is_manual_arrival = scenario["is_manual_arrival"]
        reservation.pricing_plan = scenario["pricing_plan"]
        reservation.duration_hours = scenario["duration_hours"]
        reservation.base_amount = scenario["base_amount"]
        reservation.services_amount = scenario["services_amount"]
        reservation.platform_fee_amount = scenario["platform_fee_amount"]
        reservation.final_total = scenario["final_total"]
        reservation.selected_services_snapshot = scenario["services"]
        reservation.platform_fee_snapshot = "[]"
        reservation.status = scenario["status"]
        reservation.payment_status = scenario["payment_status"]
        reservation.checked_in_at = scenario["checked_in_at"]
        reservation.checked_out_at = scenario["checked_out_at"]
        reservation.cancelled_at = None
        reservation.cancelled_by_user_id = None
        reservation.cancellation_reason = None
        reservation.cancellation_fee_amount = 0
        reservation.cancellation_credit_amount = 0

    if commit:
        await db.commit()


async def ensure_platform_fees(db, commit=True):
    fee_specs = {
        "parking": {
            "fee_mode": "hybrid",
            "fixed_amount": 1.50,
            "percentage": 5,
            "min_fee": 1.50,
            "max_fee": 15,
        },
        "car_wash": {
            "fee_mode": "hybrid",
            "fixed_amount": 2,
            "percentage": 8,
            "min_fee": 2,
            "max_fee": 12,
        },
        "insurance": {
            "fee_mode": "percentage",
            "fixed_amount": 0,
            "percentage": 10,
            "min_fee": 0,
            "max_fee": None,
        },
        "transport": {
            "fee_mode": "hybrid",
            "fixed_amount": 2.50,
            "percentage": 7,
            "min_fee": 2.50,
            "max_fee": 15,
        },
        "tour_guide": {
            "fee_mode": "percentage",
            "fixed_amount": 0,
            "percentage": 10,
            "min_fee": 0,
            "max_fee": None,
        },
        "cancellation": {
            "fee_mode": "hybrid",
            "fixed_amount": 1.00,
            "percentage": 3,
            "min_fee": 1.00,
            "max_fee": 10,
        },
    }

    result = await db.execute(
        select(PlatformFee).where(PlatformFee.service_type.in_(fee_specs.keys()))
    )
    existing = {fee.service_type: fee for fee in result.scalars().all()}

    for service_type, spec in fee_specs.items():
        fee = existing.get(service_type)
        if fee is None:
            fee = PlatformFee(service_type=service_type)
            db.add(fee)

        fee.fee_mode = spec["fee_mode"]
        fee.fixed_amount = spec["fixed_amount"]
        fee.percentage = spec["percentage"]
        fee.min_fee = spec["min_fee"]
        fee.max_fee = spec["max_fee"]
        fee.is_active = True

    if commit:
        await db.commit()


async def ensure_partner_payment_accounts(db, tenant_id=None, commit=True):
    if tenant_id is None:
        result = await db.execute(
            select(Tenant).where(Tenant.cnpj == "11222333000144")
        )
        tenant = result.scalar_one_or_none()
        if tenant is None:
            return
        tenant_id = tenant.id

    result = await db.execute(
        select(PartnerPaymentAccount).where(
            PartnerPaymentAccount.tenant_id == tenant_id,
            PartnerPaymentAccount.provider == "mercado_pago",
            PartnerPaymentAccount.is_default.is_(True),
        )
    )
    account = result.scalar_one_or_none()
    if account is None:
        account = PartnerPaymentAccount(
            tenant_id=tenant_id,
            provider="mercado_pago",
            provider_account_id="mp_seller_parkhere_seed",
            account_label="Mercado Pago parceiro seed",
            status="verified",
            is_default=True,
            is_active=True,
        )
        db.add(account)
    else:
        account.provider_account_id = "mp_seller_parkhere_seed"
        account.account_label = "Mercado Pago parceiro seed"
        account.status = "verified"
        account.is_active = True

    if commit:
        await db.commit()


if __name__ == "__main__":
    asyncio.run(seed())
