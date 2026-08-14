from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.modules.auth.auth_service import AuthService
from app.modules.auth.schemas import CustomerSignupRequest, TokenResponse

router = APIRouter(prefix="/customers", tags=["Customers"])


@router.post("/signup", response_model=TokenResponse)
async def customer_signup(
    data: CustomerSignupRequest,
    db: AsyncSession = Depends(get_db),
):
    tokens = await AuthService.CustomerSignup(db, data)
    return {
        "access_token": tokens[0],
        "refresh_token": tokens[1],
        "role": "customer",
        "account_type": "customer",
        "tenant_id": None,
    }
