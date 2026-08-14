import json

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.modules.parkings.models import Parking
from app.modules.payments.models import PartnerPaymentAccount, PaymentTransaction
from app.modules.payments.schemas import (
    CreatePaymentIntentRequest,
    PaymentIntentResponse,
    PaymentSplitResponse,
)
from app.modules.reservations.models import Reservation
from app.modules.users.models.user_model import User
from app.modules.users.models.user_model_role_enum import UserRoleEnum


class PaymentService:
    @staticmethod
    async def create_reservation_payment_intent(
        db: AsyncSession,
        reservation_id: str,
        data: CreatePaymentIntentRequest,
        current_user: User,
    ) -> PaymentIntentResponse:
        reservation = await _get_reservation(db, reservation_id)
        parking = await _get_parking(db, reservation.parking_id)
        _ensure_payment_permission(current_user, reservation, parking)
        partner_account = await _get_partner_payment_account(db, parking.tenant_id)

        if reservation.payment_status == "paid":
            raise HTTPException(status_code=409, detail="Reservation already paid")

        gross_amount = reservation.final_total or reservation.estimated_total
        platform_fee_amount = reservation.platform_fee_amount
        partner_amount = gross_amount - platform_fee_amount
        provider_fee_estimate = 0.0
        external_reference = f"reservation:{reservation.id}"
        split = [
            {
                "receiver": "parkhere_app",
                "amount": round(platform_fee_amount, 2),
                "description": "Taxa ParkHere",
            },
            {
                "receiver": partner_account.provider_account_id
                if partner_account
                else "partner_account_pending",
                "amount": round(partner_amount, 2),
                "description": "Repasse parceiro",
            },
        ]

        transaction = PaymentTransaction(
            reservation_id=reservation.id,
            tenant_id=parking.tenant_id,
            provider=settings.PAYMENT_PROVIDER,
            method=data.method,
            status="pending",
            gross_amount=gross_amount,
            platform_fee_amount=platform_fee_amount,
            partner_amount=partner_amount,
            provider_fee_estimate=provider_fee_estimate,
            checkout_url=_mock_checkout_url(external_reference),
            qr_code=_mock_pix_code(external_reference, gross_amount)
            if data.method == "pix"
            else None,
            external_reference=external_reference,
            partner_provider_account_id=partner_account.provider_account_id
            if partner_account
            else None,
            split_snapshot=json.dumps(split),
        )

        db.add(transaction)
        reservation.payment_status = "payment_pending"
        await db.commit()
        await db.refresh(transaction)

        return to_response(transaction)

    @staticmethod
    async def confirm_payment(
        db: AsyncSession,
        payment_id: str,
        current_user: User,
    ) -> PaymentIntentResponse:
        result = await db.execute(
            select(PaymentTransaction).where(PaymentTransaction.id == payment_id)
        )
        transaction = result.scalar_one_or_none()
        if transaction is None:
            raise HTTPException(status_code=404, detail="Payment not found")

        reservation = await _get_reservation(db, transaction.reservation_id)
        parking = await _get_parking(db, reservation.parking_id)
        _ensure_payment_permission(current_user, reservation, parking)
        transaction.status = "paid"
        transaction.provider_payment_id = transaction.provider_payment_id or f"mp_mock_{payment_id}"
        reservation.payment_status = "paid"
        reservation.status = "confirmed"
        await db.commit()
        await db.refresh(transaction)
        return to_response(transaction)


async def _get_reservation(db: AsyncSession, reservation_id: str) -> Reservation:
    result = await db.execute(
        select(Reservation).where(Reservation.id == reservation_id)
    )
    reservation = result.scalar_one_or_none()
    if reservation is None:
        raise HTTPException(status_code=404, detail="Reservation not found")
    return reservation


async def _get_parking(db: AsyncSession, parking_id: str) -> Parking:
    result = await db.execute(select(Parking).where(Parking.id == parking_id))
    parking = result.scalar_one_or_none()
    if parking is None:
        raise HTTPException(status_code=404, detail="Parking not found")
    return parking


async def _get_partner_payment_account(
    db: AsyncSession,
    tenant_id: str,
) -> PartnerPaymentAccount | None:
    result = await db.execute(
        select(PartnerPaymentAccount).where(
            PartnerPaymentAccount.tenant_id == tenant_id,
            PartnerPaymentAccount.provider == "mercado_pago",
            PartnerPaymentAccount.is_default.is_(True),
            PartnerPaymentAccount.is_active.is_(True),
        )
    )
    return result.scalar_one_or_none()


def _ensure_payment_permission(
    current_user: User,
    reservation: Reservation,
    parking: Parking,
) -> None:
    if current_user.role == UserRoleEnum.CUSTOMER:
        if reservation.user_id != current_user.id:
            raise HTTPException(status_code=403, detail="Reservation not allowed")
        return

    if current_user.role in {UserRoleEnum.PARKING_ADMIN, UserRoleEnum.OPERATOR}:
        if current_user.tenant_id != parking.tenant_id:
            raise HTTPException(status_code=403, detail="Reservation not allowed")
        return

    raise HTTPException(status_code=403, detail="Insufficient permissions")


def _mock_checkout_url(external_reference: str) -> str:
    return f"https://www.mercadopago.com.br/checkout/v1/mock?ref={external_reference}"


def _mock_pix_code(external_reference: str, amount: float) -> str:
    return f"00020126580014BR.GOV.BCB.PIX0136PARKHERE-{external_reference}-R${amount:.2f}"


def to_response(transaction: PaymentTransaction) -> PaymentIntentResponse:
    split = []
    if transaction.split_snapshot:
        split = [
            PaymentSplitResponse(**item)
            for item in json.loads(transaction.split_snapshot)
        ]

    return PaymentIntentResponse(
        id=transaction.id,
        reservation_id=transaction.reservation_id,
        provider=transaction.provider,
        method=transaction.method,
        status=transaction.status,
        gross_amount=transaction.gross_amount,
        platform_fee_amount=transaction.platform_fee_amount,
        partner_amount=transaction.partner_amount,
        provider_fee_estimate=transaction.provider_fee_estimate,
        checkout_url=transaction.checkout_url,
        qr_code=transaction.qr_code,
        external_reference=transaction.external_reference,
        split=split,
    )
