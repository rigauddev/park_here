from pydantic import BaseModel


class CreatePaymentIntentRequest(BaseModel):
    method: str = "pix"


class PaymentSplitResponse(BaseModel):
    receiver: str
    amount: float
    description: str


class PaymentIntentResponse(BaseModel):
    id: str
    reservation_id: str
    provider: str
    method: str
    status: str
    gross_amount: float
    platform_fee_amount: float
    partner_amount: float
    provider_fee_estimate: float
    checkout_url: str | None
    qr_code: str | None
    external_reference: str
    split: list[PaymentSplitResponse]
