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
from app.modules.platform_fees.models import PlatformFee
from app.modules.partners.models import PartnerProfile
from app.modules.payments.models import PartnerPaymentAccount
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
            await refresh_existing_seed(db)
            await ensure_partner_seed_user(db)
            await ensure_partner_operator_seed_user(db)
            await ensure_partner_profile(db)
            await ensure_demo_partner_tenants(db)
            await ensure_platform_fees(db)
            await ensure_partner_payment_accounts(db)
            print("Seed already applied.")
            print("Seed partner, parking management fields, platform fees and payment account refreshed.")
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
        partner_user = User(
            tenant_id=tenant.id,
            name="Parceiro Estacionamento",
            firt_name="Parceiro",
            email="parceiro@parkhere.test",
            password_hash=hash_password("123456"),
            phone="71999991111",
            phone_verified=True,
            email_verified=True,
            role=UserRoleEnum.PARKING_ADMIN,
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
        db.add_all([parking_admin, partner_user, operator_user, customer])
        await db.flush()
        await ensure_partner_profile(db, tenant.id, commit=False)
        demo_tenants = await ensure_demo_partner_tenants(db, commit=False)

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
                name="ParkHere Pelourinho VIP",
                address="Rua Chile, Salvador",
                lat=-12.9712,
                lng=-38.5150,
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
                name="ParkHere Comercio Express",
                address="Av. Estados Unidos, Salvador",
                lat=-12.9688,
                lng=-38.5096,
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
    demo_tenants = await ensure_demo_partner_tenants(db, commit=False)

    parking_specs = {
        "Estacionamento Central ParkHere": {
            "tenant_id": main_tenant.id if main_tenant else None,
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
            "tenant_id": demo_tenants["pelourinho"].id,
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
            "tenant_id": demo_tenants["comercio"].id,
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
    }

    result = await db.execute(
        select(Parking).where(Parking.name.in_(parking_specs.keys()))
    )
    for parking in result.scalars().all():
        for field, value in parking_specs[parking.name].items():
            if value is not None:
                setattr(parking, field, value)
        parking.has_covered_area = parking.covered_spots > 0

    await db.commit()


async def ensure_demo_partner_tenants(db, commit=True):
    specs = {
        "pelourinho": {
            "name": "Pelourinho Parking Partners",
            "cnpj": "22333444000155",
            "email": "operacao.pelourinho@parkhere.test",
            "profile_name": "ParkHere Pelourinho VIP",
            "user_email": "pelourinho@parkhere.test",
        },
        "comercio": {
            "name": "Comercio Parking Partners",
            "cnpj": "33444555000166",
            "email": "operacao.comercio@parkhere.test",
            "profile_name": "ParkHere Comercio Express",
            "user_email": "comercio@parkhere.test",
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
                    role=UserRoleEnum.PARKING_ADMIN,
                )
            )
        else:
            user.tenant_id = tenant.id
            user.role = UserRoleEnum.PARKING_ADMIN
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
            role=UserRoleEnum.PARKING_ADMIN,
        )
        db.add(user)
    else:
        user.tenant_id = tenant.id
        user.role = UserRoleEnum.PARKING_ADMIN
        user.phone_verified = True
        user.email_verified = True
        user.is_active = True

    if commit:
        await db.commit()


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
        )
        db.add(user)
    else:
        user.tenant_id = tenant.id
        user.role = UserRoleEnum.OPERATOR
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
            company_name="ParkHere Salvador Centro",
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
        profile.company_name = "ParkHere Salvador Centro"
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
