import json
from decimal import Decimal
from datetime import datetime

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.modules.parkings.models import Parking
from app.modules.payments.models import (
    PartnerFeeDebt,
    PartnerFeeSettlement,
    PartnerPaymentAccount,
    PaymentTransaction,
)
from app.modules.tenants.models.tenant_models import Tenant
from app.modules.payments.schemas import (
    CreatePaymentIntentRequest,
    PaymentIntentResponse,
    PaymentSplitResponse,
)
from app.modules.reservations.models import Reservation
from app.modules.reservations.service import calculate_checkout_excess
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
        _ensure_payable_reservation(reservation)
        if settings.PAYMENT_PROVIDER != "mock":
            raise HTTPException(
                status_code=503,
                detail="Mercado Pago integration is not enabled; no payment was created",
            )
        if data.method == "cash" and current_user.role == UserRoleEnum.CUSTOMER:
            raise HTTPException(
                status_code=403,
                detail="Cash is recorded by parking staff only",
            )
        partner_account = await _get_partner_payment_account(db, parking.tenant_id)

        purpose = data.purpose
        if purpose not in {"reservation", "checkout_excess"}:
            raise HTTPException(status_code=422, detail="Invalid payment purpose")

        if purpose == "reservation" and reservation.payment_status == "paid":
            raise HTTPException(status_code=409, detail="Reservation already paid")

        if purpose == "checkout_excess":
            if reservation.status != "checked_in":
                raise HTTPException(status_code=409, detail="Checkout excess requires check-in")
            excess_minutes, excess_amount = calculate_checkout_excess(
                reservation,
                parking,
            )
            reservation.checkout_excess_minutes = excess_minutes
            reservation.checkout_excess_amount = excess_amount
            if reservation.checkout_excess_amount <= 0:
                raise HTTPException(status_code=409, detail="No checkout excess to pay")
            if reservation.checkout_excess_paid_at is not None:
                raise HTTPException(status_code=409, detail="Checkout excess already paid")
            gross_amount = reservation.checkout_excess_amount
            platform_fee_amount = 0.0
        else:
            gross_amount = reservation.final_total or reservation.estimated_total
            platform_fee_amount = reservation.platform_fee_amount
            if reservation.status == "checked_in" and reservation.pricing_plan == "hourly":
                excess_minutes, excess_amount = calculate_checkout_excess(
                    reservation,
                    parking,
                )
                reservation.checkout_excess_minutes = excess_minutes
                reservation.checkout_excess_amount = excess_amount
                gross_amount += excess_amount

        if data.method == "cash" and (
            data.cash_received is None or data.cash_received < gross_amount
        ):
            raise HTTPException(status_code=422, detail="Cash received must cover the total")
        pending = await db.scalar(
            select(PaymentTransaction)
            .where(
                PaymentTransaction.reservation_id == reservation.id,
                PaymentTransaction.payment_purpose == purpose,
                PaymentTransaction.status == "pending",
                PaymentTransaction.method == data.method,
                PaymentTransaction.provider == settings.PAYMENT_PROVIDER,
            )
            .order_by(PaymentTransaction.created_at.desc())
            .limit(1)
            .with_for_update()
            .execution_options(populate_existing=True)
        )
        if pending and round(pending.gross_amount, 2) == round(gross_amount, 2):
            if data.method == "cash":
                pending.cash_received = data.cash_received
            await db.commit()
            return to_response(pending)
        if pending:
            pending.status = "superseded"
        partner_amount = gross_amount - platform_fee_amount
        provider_fee_estimate = 0.0
        external_reference = f"{purpose}:{reservation.id}"
        split = [
            {
                "receiver": "parkhere_app",
                "amount": round(platform_fee_amount, 2),
                "description": "Taxa ParkHere"
                if purpose == "reservation"
                else "Taxa ParkHere excedente",
            },
            {
                "receiver": partner_account.provider_account_id
                if partner_account
                else "partner_account_pending",
                "amount": round(partner_amount, 2),
                "description": "Repasse parceiro"
                if purpose == "reservation"
                else "Excedente de permanencia",
            },
        ]

        transaction = PaymentTransaction(
            reservation_id=reservation.id,
            tenant_id=parking.tenant_id,
            provider=settings.PAYMENT_PROVIDER,
            method=data.method,
            cash_received=data.cash_received if data.method == "cash" else None,
            payment_purpose=purpose,
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
        reservation.payment_status = (
            "checkout_excess_pending"
            if purpose == "checkout_excess"
            else "payment_pending"
        )
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
        # Re-read after acquiring the tenant/reservation locks: concurrent confirmations
        # must observe the committed transaction, not the earlier identity-map value.
        await db.refresh(transaction)
        _ensure_payment_permission(current_user, reservation, parking)
        if transaction.method == "cash" and current_user.role == UserRoleEnum.CUSTOMER:
            raise HTTPException(status_code=403, detail="Cash is staff only")
        if settings.PAYMENT_PROVIDER != "mock" or transaction.provider != "mock":
            raise HTTPException(status_code=403, detail="Provider confirmation required")
        if transaction.status == "paid":
            return to_response(transaction)
        _ensure_payable_reservation(reservation)
        if transaction.status != "pending":
            raise HTTPException(status_code=409, detail="Payment is not pending")
        if (
            transaction.payment_purpose == "reservation"
            and reservation.payment_status == "paid"
        ):
            raise HTTPException(status_code=409, detail="Reservation already paid")
        if (
            transaction.payment_purpose == "checkout_excess"
            and reservation.checkout_excess_paid_at is not None
        ):
            raise HTTPException(status_code=409, detail="Checkout excess already paid")
        await apply_cash_fee_ledger(db, transaction)
        transaction.status = "paid"
        transaction.provider_payment_id = transaction.provider_payment_id or f"mp_mock_{payment_id}"
        if transaction.payment_purpose == "checkout_excess":
            reservation.checkout_excess_paid_at = datetime.utcnow()
            reservation.payment_status = "paid"
        else:
            if reservation.checkout_excess_amount > 0:
                reservation.checkout_excess_paid_at = datetime.utcnow()
            reservation.payment_status = "paid"
        if transaction.payment_purpose == "reservation" and reservation.status != "checked_in":
            reservation.status = "confirmed"
        await db.commit()
        await db.refresh(transaction)
        return to_response(transaction)


async def _get_reservation(db: AsyncSession, reservation_id: str) -> Reservation:
    tenant_id = await db.scalar(
        select(Parking.tenant_id)
        .join(Reservation, Reservation.parking_id == Parking.id)
        .where(Reservation.id == reservation_id)
    )
    if tenant_id is not None:
        await db.scalar(select(Tenant).where(Tenant.id == tenant_id).with_for_update())
    parking_id = await db.scalar(select(Reservation.parking_id).where(Reservation.id == reservation_id))
    if parking_id is not None:
        await db.scalar(select(Parking).where(Parking.id == parking_id).with_for_update())
    result = await db.execute(
        select(Reservation)
        .where(Reservation.id == reservation_id)
        .with_for_update()
        .execution_options(populate_existing=True)
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

    if current_user.role in {UserRoleEnum.PARTNER_MANAGER, UserRoleEnum.PARKING_ADMIN}:
        if current_user.tenant_id != parking.tenant_id:
            raise HTTPException(status_code=403, detail="Reservation not allowed")
        return

    if current_user.role == UserRoleEnum.OPERATOR:
        if current_user.tenant_id != parking.tenant_id:
            raise HTTPException(status_code=403, detail="Reservation not allowed")
        return

    raise HTTPException(status_code=403, detail="Insufficient permissions")


def _ensure_payable_reservation(reservation: Reservation) -> None:
    if reservation.status not in {"pre_reserved", "confirmed", "checked_in"}:
        raise HTTPException(status_code=409, detail="Reservation cannot be paid in this status")
    if (reservation.status == "pre_reserved" and reservation.hold_expires_at
            and reservation.hold_expires_at <= datetime.utcnow()):
        raise HTTPException(status_code=409, detail="Pre-reservation expired")


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
        is_simulated=transaction.provider == "mock",
        method=transaction.method,
        purpose=transaction.payment_purpose,
        status=transaction.status,
        gross_amount=transaction.gross_amount,
        withheld_fee_amount=float(transaction.withheld_fee_amount or 0),
        cash_received=float(transaction.cash_received)
        if transaction.cash_received is not None
        else None,
        platform_fee_amount=transaction.platform_fee_amount,
        partner_amount=transaction.partner_amount,
        provider_fee_estimate=transaction.provider_fee_estimate,
        checkout_url=transaction.checkout_url,
        qr_code=transaction.qr_code,
        external_reference=transaction.external_reference,
        split=split,
    )


async def apply_cash_fee_ledger(db, transaction):
    """Tenant is locked by the caller; debit/settlements commit with payment status."""
    if transaction.method == "cash":
        if transaction.cash_received is None or transaction.cash_received < Decimal(
            str(transaction.gross_amount)
        ):
            raise HTTPException(status_code=422, detail="Cash received must cover the total")
        amount = Decimal(str(transaction.platform_fee_amount)).quantize(Decimal("0.01"))
        if amount > 0:
            db.add(
                PartnerFeeDebt(
                    tenant_id=transaction.tenant_id,
                    reservation_id=transaction.reservation_id,
                    source_payment_id=transaction.id,
                    amount=amount,
                    remaining_amount=amount,
                    description=(
                        f"Taxa referente a reserva {transaction.reservation_id}, "
                        "recebido em dinheiro"
                    ),
                )
            )
        return
    available = max(Decimal(str(transaction.partner_amount)), Decimal("0")).quantize(Decimal("0.01"))
    debts = (
        await db.scalars(
            select(PartnerFeeDebt)
            .where(
                PartnerFeeDebt.tenant_id == transaction.tenant_id,
                PartnerFeeDebt.remaining_amount > 0,
            )
            .order_by(PartnerFeeDebt.created_at, PartnerFeeDebt.id)
            .with_for_update()
            .execution_options(populate_existing=True)
        )
    ).all()
    withheld = Decimal("0.00")
    for debt in debts:
        applied = min(debt.remaining_amount, available)
        if applied <= 0:
            break
        debt.remaining_amount -= applied
        available -= applied
        withheld += applied
        db.add(
            PartnerFeeSettlement(
                debt_id=debt.id,
                payment_id=transaction.id,
                amount=applied,
            )
        )
    transaction.withheld_fee_amount = withheld
    transaction.partner_amount = float(available)
    transaction.split_snapshot = json.dumps([
        {"receiver": "parkhere_app", "amount": transaction.platform_fee_amount,
         "description": "Taxa ParkHere desta reserva"},
        {"receiver": "parkhere_app", "amount": float(withheld),
         "description": "Compensacao de taxas recebidas em dinheiro"},
        {"receiver": transaction.partner_provider_account_id or "partner_account_pending",
         "amount": float(available), "description": "Repasse liquido parceiro"},
    ])
