from app.modules.auth import auth_service
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from .schemas import (
    CompletePasswordResetRequest,
    EmailCodeRequest,
    MFARequest,
    PasswordResetRequest,
    RegisterParkingSchema,
    LoginRequest,
    TokenResponse,
    VerifyEmailCodeRequest,
    VerifyPasswordResetCodeRequest,
    CustomerSignupRequest,
    CreateUserRequest,
)
from app.modules.auth.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Auth"])

@router.post("/register-parking")
async def register_parking(
    data: RegisterParkingSchema,
    db: AsyncSession = Depends(get_db)
):

    user = await AuthService.register_parking(
        db=db,
        tenant_name=data.tenant_name,
        name=data.name,
        firt_name=data.firt_name,
        email=data.email,
        password=data.password,
        phone=data.phone,
        cnpj=data.cnpj
    )

    return {
        "message": "Parking created. MFA code sent to email."
    }

# @router.post("/user-register", response_model=TokenResponse)
# async def UserSignup(data: CreateUserRequest, db: AsyncSession = Depends(get_db)):
#     tokens = await AuthService.UserSignup(db, data)
#     return {
#         "access_token": tokens[0],
#         "refresh_token": tokens[1],
#     }

# @router.post("/customer-signup", response_model=TokenResponse)
# async def CustomerSignup(data: CustomerSignupRequest, db: AsyncSession = Depends(get_db)):
#     tokens = await AuthService.CustomerSignup(db, data)
#     return {
#         "access_token": tokens[0],
#         "refresh_token": tokens[1],
    # }

@router.post("/login")
async def login(data: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await AuthService.login(db, data)
    if not result:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return result

@router.post("/verify-mfa", response_model=TokenResponse)
async def verify_mfa(data: MFARequest, db: AsyncSession = Depends(get_db)):
    tokens = await AuthService.verify_mfa(db, data)
    if not tokens:
        raise HTTPException(status_code=401, detail="Invalid or expired code")

    return tokens

@router.post("/email/request-code")
async def request_email_code(data: EmailCodeRequest):
    return await AuthService.request_email_verification(data.email)

@router.post("/email/verify-code")
async def verify_email_code(data: VerifyEmailCodeRequest):
    result = await AuthService.verify_email_code(data.email_token, data.code)
    if not result:
        raise HTTPException(status_code=401, detail="Invalid or expired code")
    return result

@router.post("/password/request-reset")
async def request_password_reset(
    data: PasswordResetRequest,
    db: AsyncSession = Depends(get_db),
):
    return await AuthService.request_password_reset(db, data.email)

@router.post("/password/verify-code")
async def verify_password_reset_code(data: VerifyPasswordResetCodeRequest):
    result = await AuthService.verify_password_reset_code(data.reset_token, data.code)
    if not result:
        raise HTTPException(status_code=401, detail="Invalid or expired code")
    return result

@router.post("/password/reset")
async def complete_password_reset(
    data: CompletePasswordResetRequest,
    db: AsyncSession = Depends(get_db),
):
    result = await AuthService.complete_password_reset(
        db,
        data.reset_token,
        data.code,
        data.new_password,
    )
    if not result:
        raise HTTPException(status_code=401, detail="Invalid or expired code")
    return result
