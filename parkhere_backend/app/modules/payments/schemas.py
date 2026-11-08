from typing import Literal

from pydantic import BaseModel, Field


class CreatePaymentIntentRequest(BaseModel):
    method: Literal["pix", "credit_card", "debit_card", "cash"] = "pix"
    cash_received: float | None = Field(default=None, ge=0, allow_inf_nan=False)
    purpose: Literal["reservation", "checkout_excess"] = "reservation"
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)


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
    customer_fee_amount: float = 0
    establishment_fee_amount: float = 0
    partner_amount: float
    withheld_fee_amount: float = 0
    cash_received: float | None = None
    provider_fee_estimate: float
    checkout_url: str | None
    qr_code: str | None
    external_reference: str
    split: list[PaymentSplitResponse]


class TransparentOrderRequest(BaseModel):
    method: Literal["pix", "credit_card", "debit_card"] = "credit_card"
    purpose: Literal["reservation", "checkout_excess"] = "reservation"
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)


class TransparentOrderResponse(BaseModel):
    transaction_id: str
    reservation_id: str
    provider: str
    order_id: str
    client_token: str | None = None
    status: str
    amount: float
    method: str
    external_reference: str
    qr_code: str | None = None
    qr_code_base64: str | None = None
