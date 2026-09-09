from app.modules.users.models.user_schema import UserCreate, UserResponse
from app.modules.users.user_service import create_parking_user, create_customer_user
from fastapi import APIRouter, Depends, HTTPException
from app.core.dependencies import get_current_user, require_role, get_db
from sqlalchemy.ext.asyncio import AsyncSession
from app.modules.users.models.user_model import User
from app.modules.users.models.user_model_role_enum import UserRoleEnum
from sqlalchemy import select


router = APIRouter(prefix="/users", tags=["Users"])

@router.post("/create", response_model=UserResponse)
async def create_user(
    data: UserCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):

    if current_user.role not in {
        UserRoleEnum.PARTNER_MANAGER,
        UserRoleEnum.PARKING_ADMIN,
    }:
        raise HTTPException(status_code=403, detail="Insufficient permissions")

    user = await create_parking_user(
        db=db,
        data=data,
        tenant_id=current_user.tenant_id
    )

    return user

@router.get("/users_list")
async def list_users(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User))
    users = result.scalars().all()
    return users
