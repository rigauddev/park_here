import hmac
from datetime import datetime

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.payments.schemas import (
    CreatePaymentIntentRequest,
    PaymentIntentResponse,
    TransparentOrderRequest,
    TransparentOrderResponse,
)
from app.modules.payments.service import PaymentService
from app.modules.users.models.user_model import User
from app.core.config import settings
from app.modules.payments.models import PaymentTransaction
from app.modules.reservations.models import Reservation
from app.modules.payments.mercado_pago_client import MercadoPagoClient, MercadoPagoError

router = APIRouter(prefix="/payments", tags=["Payments"])


@router.post("/webhooks/mercado-pago")
async def mercado_pago_webhook(
    request: Request,
    x_webhook_secret: str | None = Header(default=None),
    db: AsyncSession = Depends(get_db),
):
    """Reconcile approved Mercado Pago payments without trusting the client app."""
    if settings.MERCADO_PAGO_WEBHOOK_SECRET and not hmac.compare_digest(
        x_webhook_secret or "", settings.MERCADO_PAGO_WEBHOOK_SECRET
    ):
        raise HTTPException(status_code=401, detail="Webhook não autorizado")
    payload = await request.json()
    payment_id = str((payload.get("data") or {}).get("id") or payload.get("id") or "")
    if not payment_id:
        return {"received": True, "processed": False}
    client = MercadoPagoClient()
    try:
        provider_payment = await client.get_payment(payment_id)
    except MercadoPagoError:
        # Checkout Transparente Orders webhooks identify the order, while the
        # legacy preference flow identifies a payment. Reconcile both shapes.
        try:
            provider_payment = await client.get_order(payment_id)
        except MercadoPagoError as exc:
            raise HTTPException(status_code=502, detail=str(exc)) from exc
    order_transactions = provider_payment.get("transactions") or []
    nested_payments = [
        payment
        for transaction in order_transactions
        for payment in (transaction.get("payments") or [])
    ]
    payment_snapshot = nested_payments[0] if nested_payments else provider_payment
    external_reference = (
        payment_snapshot.get("external_reference")
        or provider_payment.get("external_reference")
    )
    transaction = await db.scalar(select(PaymentTransaction).where(
        PaymentTransaction.provider == "mercado_pago",
        PaymentTransaction.provider_payment_id == payment_id,
    ))
    if transaction is None and external_reference:
        transaction = await db.scalar(select(PaymentTransaction).where(
            PaymentTransaction.external_reference == external_reference,
        ))
    if transaction is None:
        return {"received": True, "processed": False}
    transaction.provider_payment_id = payment_id
    status = payment_snapshot.get("status") or provider_payment.get("status")
    provider_payment_id = str(payment_snapshot.get("id") or payment_id)
    if transaction is None and provider_payment_id != payment_id:
        transaction = await db.scalar(select(PaymentTransaction).where(
            PaymentTransaction.provider == "mercado_pago",
            PaymentTransaction.provider_payment_id == provider_payment_id,
        ))
    if status in {"approved", "accredited"} and transaction.status != "paid":
        transaction.status = "paid"
        reservation = await db.scalar(select(Reservation).where(Reservation.id == transaction.reservation_id))
        if reservation is not None:
            reservation.payment_status = "paid"
            reservation.payment_method = transaction.method
            reservation.payment_confirmed_at = datetime.utcnow()
            if transaction.payment_purpose == "reservation" and reservation.status not in {"checked_in", "completed"}:
                reservation.status = "confirmed"
    elif status in {"rejected", "cancelled", "refunded", "charged_back"}:
        transaction.status = status
    await db.commit()
    return {"received": True, "processed": True, "status": status}


@router.get('/reservations/{reservation_id}/quote')
async def reservation_payment_quote(
    reservation_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await PaymentService.reservation_payment_quote(db, reservation_id, current_user)


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


@router.post(
    "/reservations/{reservation_id}/transparent-order",
    response_model=TransparentOrderResponse,
)
async def create_transparent_order(
    reservation_id: str,
    data: TransparentOrderRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await PaymentService.create_transparent_order(
        db, reservation_id, data, current_user
    )


@router.post("/{payment_id}/confirm", response_model=PaymentIntentResponse)
async def confirm_payment(
    payment_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await PaymentService.confirm_payment(db, payment_id, current_user)
