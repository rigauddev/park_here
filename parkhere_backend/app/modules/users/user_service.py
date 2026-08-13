from sqlalchemy.ext.asyncio import AsyncSession
from app.modules.users.models.user_model import User
from app.modules.users.models.user_schema import UserCreate
from app.core.security import hash_password
from app.modules.users.models.user_model_role_enum import UserRoleEnum


async def create_parking_user(
    db: AsyncSession,
    data: UserCreate,
    tenant_id: str
):

    if data.role == UserRoleEnum.CUSTOMER:
        raise Exception("Use rota de registro do app")

    user = User(
        tenant_id=tenant_id,
        name=data.name,
        firt_name=data.firt_name,
        email=data.email,
        password_hash=hash_password(data.password),
        phone=data.phone,
        role=data.role,
        commission_percentage=data.commission_percentage
    )

    db.add(user)
    await db.commit()
    await db.refresh(user)

    return user

def create_customer_user(
    db: AsyncSession,
    data: UserCreate,
    tenant_id: str
):

    user = User(
        tenant_id=tenant_id,
        name=data.name,
        firt_name=data.firt_name,
        email=data.email,
        password_hash=hash_password(data.password),
        phone=data.phone,
        role=UserRoleEnum.CUSTOMER
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return user