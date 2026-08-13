from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime

from app.core.config import settings
from app.core.database import get_db
from app.modules.users.models.user_model import User
from app.modules.tenants.models.tenant_models import Tenant, TenantStatusEnum

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
):
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        email: str = payload.get("sub")
        tenant_id: str = payload.get("tenant_id")

        if not email or not tenant_id:
            raise HTTPException(status_code=401, detail="Invalid token")

    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

    # Buscar usuário
    result = await db.execute(
        select(User).where(User.email == email)
    )
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    # Buscar tenant
    result = await db.execute(
        select(Tenant).where(Tenant.id == tenant_id)
    )
    tenant = result.scalar_one_or_none()

    if not tenant:
        raise HTTPException(status_code=403, detail="Tenant not found")

    # Verificar status do tenant
    if tenant.status == TenantStatusEnum.SUSPENDED:
        raise HTTPException(status_code=403, detail="Tenant suspended")

    if tenant.status == TenantStatusEnum.TRIAL:
        if tenant.trial_ends_at and tenant.trial_ends_at < datetime.utcnow():
            raise HTTPException(status_code=403, detail="Trial expired")

    return user

def require_role(required_roles: list):
    async def role_checker(user = Depends(get_current_user)):
        if user.role.value not in required_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions"
            )
        return user
    return role_checker

