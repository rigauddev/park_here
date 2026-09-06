from typing import Literal

from pydantic import BaseModel, Field


class CreatePaymentIntentRequest(BaseModel):
    method: Literal["pix", "credit_card", "debit_card", "cash"] = "pix"
    cash_received: float | None = Field(default=None, ge=0, allow_inf_nan=False)
    purpose: Literal["reservation", "checkout_excess"] = "reservation"


class PaymentSplitResponse(BaseModel):
    receiver: str
    amount: float
    description: str


class PaymentIntentResponse(BaseModel):
    id: str
    reservation_id: str
    provider: str
    is_simulated: bool = False
    method: str
    purpose: str
    status: str
    gross_amount: float
    platform_fee_amount: float
    partner_amount: float
    withheld_fee_amount: float = 0
    cash_received: float | None = None
    provider_fee_estimate: float
    checkout_url: str | None
    qr_code: str | None
    external_reference: str
    split: list[PaymentSplitResponse]
