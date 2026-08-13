import asyncio
from app.core.database import AsyncSessionLocal
from app.modules.users.models.user_model import User, UserRoleEnum
from app.modules.tenants.models.tenant_models import Tenant
from app.modules.tenants.models.tenant_model_plan_enum import PlanEnum
from app.modules.tenants.models.tenant_model_status_enum import TenantStatusEnum

from app.core.security import hash_password


async def create_user():
    async with AsyncSessionLocal() as db:

        tenant = Tenant(
            name="Estacionamento Teste",
            cnpj="000000000001",
            email="admin@teste.com",
            plan=PlanEnum.PRO,
            status=TenantStatusEnum.ACTIVE
        )

        db.add(tenant)
        await db.flush()

        user = User(
            tenant_id=tenant.id,
            name="Admin Teste",
            firt_name="woner",
            email="admin@teste.com",
            password_hash=hash_password("123456"),
            role=UserRoleEnum.PARKING_ADMIN
        )

        db.add(user)
        await db.commit()

        print("✅ Usuário de teste criado!")
        print("Email: admin@teste.com")
        print("Senha: 123456")


if __name__ == "__main__":
    asyncio.run(create_user())