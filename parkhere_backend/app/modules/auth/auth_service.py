from app.modules.tenants.models.tenant_model_plan_enum import PlanEnum
from app.modules.tenants.models.tenant_model_status_enum import TenantStatusEnum
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.modules.tenants.models.tenant_models import Tenant
from app.modules.users.models.user_model import User
from app.modules.users.models.user_model_role_enum import UserRoleEnum
from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    verify_password,
)
from app.core.mfa_service import (
    create_mfa_token,
    create_temp_login_token,
    generate_otp,
    verify_mfa_token,
)
from app.core.email_service import EmailService
from app.core.sms_service import SMSService

class AuthService:
    DEV_EMAIL_CODE = "000000"

    @staticmethod
    async def register_parking(
        db: AsyncSession,
        tenant_name: str,
        name: str, 
        firt_name: str,
        email: str,
        password: str,
        phone: str,
        cnpj: str
    ):

        try:

            tenant = Tenant(
                name=tenant_name,
                cnpj=cnpj,
                email=email,
                plan=PlanEnum.PRO,
                status=TenantStatusEnum.TRIAL
            )

            db.add(tenant)
            await db.flush()

            admin_user = User(
                tenant_id=tenant.id,
                name=name,
                firt_name=firt_name,
                email=email,
                password_hash=hash_password(password),
                phone=phone,
                role=UserRoleEnum.PARTNER_MANAGER
            )

            db.add(admin_user)

            await db.commit()

            # gerar MFA
            code = generate_otp()
            print(code)

            await EmailService.send_mfa_email(email, code)

            return admin_user

        except Exception as e:

            await db.rollback()
            raise e

    @staticmethod
    async def register_partner(db: AsyncSession, data):
        normalized_email = data.email.strip().lower()
        existing = await db.execute(select(User).where(User.email == normalized_email))
        if existing.scalar_one_or_none():
            from fastapi import HTTPException
            raise HTTPException(status_code=409, detail="Email already registered")

        tenant = Tenant(
            name=data.company_name,
            cnpj=data.cnpj,
            email=normalized_email,
            plan=PlanEnum.FREE,
            status=TenantStatusEnum.TRIAL,
        )
        db.add(tenant)
        await db.flush()

        partner_user = User(
            tenant_id=tenant.id,
            name=data.responsible_name,
            firt_name=data.responsible_name.split(" ")[0],
            email=normalized_email,
            password_hash=hash_password(data.password),
            phone=data.phone,
            role=UserRoleEnum.PARTNER_MANAGER,
        )
        db.add(partner_user)

        return partner_user
    
    @staticmethod
    async def UserSignup(db: AsyncSession, data):
        print(data)

        user = User(
            tenant_id="f9d85308-d9fc-4b1d-bd8b-e784c8b0cf2c",
            name=data.name,
            firt_name=data.firt_name,
            phone=data.phone,
            email=data.email,
            password_hash=hash_password(data.password),
            role={ "OPERATOR": UserRoleEnum.OPERATOR, "TOUR_GUIDE": UserRoleEnum.TOUR_GUIDE}[data.role]
        )
        db.add(user)

        await db.commit()

        access_token = create_access_token({
            "sub": user.email,
            "tenant_id": user.tenant_id,
            "role": user.role.value
        })

        refresh_token = create_refresh_token({
            "sub": user.email
        })

        return access_token, refresh_token
    @staticmethod
    async def CustomerSignup(db: AsyncSession, data):

        # Criar customer
        user = User(
            name=data.name,
            firt_name=data.firt_name,
            phone=data.phone,
            email=data.email,
            password_hash=hash_password(data.password),
            role=UserRoleEnum.CUSTOMER
        )
        db.add(user)

        await db.commit()

        access_token = create_access_token({
            "sub": user.email,
            "role": user.role.value
        })

        refresh_token = create_refresh_token({
            "sub": user.email
        })

        return access_token, refresh_token

    @staticmethod
    async def request_email_verification(email: str):
        normalized_email = email.strip().lower()
        token = create_mfa_token(normalized_email, AuthService.DEV_EMAIL_CODE)
        EmailService.send_email(
            to_email=normalized_email,
            subject="Codigo de validacao ParkHere",
            body=f"<h1>{AuthService.DEV_EMAIL_CODE}</h1>",
        )
        print(f"Email validation code for {normalized_email}: {AuthService.DEV_EMAIL_CODE}")
        return {"email_token": token}

    @staticmethod
    async def verify_email_code(email_token: str, code: str):
        email = verify_mfa_token(email_token, code)
        if not email:
            return None
        return {"email": email, "verified": True}

    @staticmethod
    async def request_password_reset(db: AsyncSession, email: str):
        normalized_email = email.strip().lower()
        result = await db.execute(select(User).where(User.email == normalized_email))
        user = result.scalar_one_or_none()

        if user:
            token = create_mfa_token(user.id, AuthService.DEV_EMAIL_CODE)
            EmailService.send_email(
                to_email=normalized_email,
                subject="Recuperacao de senha ParkHere",
                body=f"<h1>{AuthService.DEV_EMAIL_CODE}</h1>",
            )
            print(f"Password reset code for {normalized_email}: {AuthService.DEV_EMAIL_CODE}")
        else:
            token = create_mfa_token("unknown", AuthService.DEV_EMAIL_CODE)

        return {"reset_token": token}

    @staticmethod
    async def verify_password_reset_code(reset_token: str, code: str):
        user_id = verify_mfa_token(reset_token, code)
        if not user_id or user_id == "unknown":
            return None
        return {"verified": True}

    @staticmethod
    async def complete_password_reset(
        db: AsyncSession,
        reset_token: str,
        code: str,
        new_password: str,
    ):
        user_id = verify_mfa_token(reset_token, code)
        if not user_id or user_id == "unknown":
            return None

        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            return None

        user.password_hash = hash_password(new_password)
        await db.commit()
        return {"password_updated": True}

    @staticmethod
    async def login(db: AsyncSession, data):
        email = data.email.strip().lower()

        result = await db.execute(
            select(User).where(User.email == email)
        )
        user = result.scalar_one_or_none()

        if not user:
            return None

        if not verify_password(data.password, user.password_hash):
            return None

        account_type = getattr(data, "account_type", None)
        if account_type == "customer" and user.role != UserRoleEnum.CUSTOMER:
            return None

        if account_type == "partner" and user.role in {
            UserRoleEnum.CUSTOMER,
            UserRoleEnum.SUPER_ADMIN,
        }:
            return None

        methods = []

        if user.email_verified:
            methods.append("email")

        if user.phone and user.phone_verified:
            methods.append("sms")

        # MVP: código fixo para testes locais. V2: enviar OTP real por email/SMS.
        mfa_code = "000000"
        print(f"Login MFA code for {user.email}: {mfa_code}")
        mfa_token = create_mfa_token(user.id, mfa_code)

        return {
            "mfa_required": True,
            "mfa_token": mfa_token,
            "available_methods": methods
        }
    
    @staticmethod
    async def verify_mfa(db: AsyncSession, data):

        user_id = verify_mfa_token(data.mfa_token, data.code)

        if not user_id:
            return None

        result = await db.execute(
            select(User).where(User.id == user_id)
        )
        user = result.scalar_one_or_none()

        if not user:
            return None

        access_token = create_access_token({
            "sub": user.email,
            "tenant_id": user.tenant_id,
            "role": user.role.value
        })

        refresh_token = create_refresh_token({
            "sub": user.email
        })

        account_type = (
            "customer" if user.role == UserRoleEnum.CUSTOMER else "partner"
        )

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "role": user.role.value,
            "account_type": account_type,
            "tenant_id": user.tenant_id,
        }
    
    @staticmethod
    async def send_mfa_code(db: AsyncSession, mfa_token: str, method: str):

        try:
            payload = jwt.decode(
                mfa_token,
                settings.MFA_SECRET_KEY,
                algorithms=["HS256"]
            )

            if payload.get("type") != "mfa_init":
                return None

            user_id = payload.get("sub")

        except JWTError:
            return None

        result = await db.execute(
            select(User).where(User.id == user_id)
        )
        user = result.scalar_one_or_none()

        if not user:
            return None

        otp = generate_otp()

        print(f"📲 SMS enviado para {user.email}: Seu código de verificação é: {otp}")

        new_mfa_token = create_mfa_token(user.id, otp)

        print("📲 SMS enviado para {user.phone}: Seu código de verificação é: {otp}", {new_mfa_token})

        if method == "email":
            EmailService.send_email(
                to_email=user.email,
                subject="Seu código de verificação",
                body=f"<h1>{otp}</h1>"
            )

        elif method == "sms" and user.phone_verified:
            SMSService.send_sms(
                user.phone,
                f"Seu código ParkFinder é: {otp}"
            )

        print(f"📲 SMS enviado para {user.phone}: Seu código ParkFinder é: {otp}")

        return {"mfa_token": new_mfa_token}
