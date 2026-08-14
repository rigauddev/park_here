from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.payments.schemas import (
    CreatePaymentIntentRequest,
    PaymentIntentResponse,
)
from app.modules.payments.service import PaymentService
from app.modules.users.models.user_model import User

router = APIRouter(prefix="/payments", tags=["Payments"])


@router.post(
    "/reservations/{reservation_id}/intent",
    response_model=PaymentIntentResponse,
)
async def create_reservation_payment_intent(
    reservation_id: str,
    data: CreatePaymentIntentRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await PaymentService.create_reservation_payment_intent(
        db,
        reservation_id,
        data,
        current_user,
    )


@router.post("/{payment_id}/confirm", response_model=PaymentIntentResponse)
async def confirm_payment(
    payment_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await PaymentService.confirm_payment(db, payment_id, current_user)
