import re

from pydantic import BaseModel, Field, field_validator


class ReservationServiceSnapshot(BaseModel):
    code: str
    name: str
    price: float


class ReservationPlatformFeeSnapshot(BaseModel):
    service_type: str
    base_amount: float
    fee_amount: float
    fee_mode: str
    fixed_amount: float
    percentage: float


class PreCheckinReservationRequest(BaseModel):
    parking_id: str
    route_minutes: int
    estimated_total: float | None = None
    vehicle_id: str | None = None
    spot_code: str | None = None
    arrival_estimate_at: str | None = None
    is_manual_arrival: bool = False
    arrival_now: bool = False
    walk_in_plate: str | None = None
    walk_in_phone: str | None = None
    spot_type: str = "uncovered"
    pricing_plan: str = "hourly"
    duration_hours: int = 1
    service_codes: list[str] = Field(default_factory=list)


    @field_validator("walk_in_plate")
    @classmethod
    def validate_plate(cls, value):
        if value is None:
            return value
        value = re.sub(r"[\s-]", "", value).upper()
        if not re.fullmatch(r"[A-Z]{3}[0-9][A-Z0-9][0-9]{2}", value):
            raise ValueError("Informe uma placa brasileira valida")
        return value

    @field_validator("walk_in_phone")
    @classmethod
    def validate_phone(cls, value):
        if value is None:
            return value
        value = re.sub(r"\D", "", value)
        if len(value) in {12, 13} and value.startswith("55"):
            value = value[2:]
        if len(value) not in {10, 11} or value[:2] == '00':
            raise ValueError("Informe telefone com DDD")
        if len(value) == 11 and value[2] != '9':
            raise ValueError("Celular deve seguir o formato brasileiro")
        return value


class CancelReservationRequest(BaseModel):
    reason: str | None = None


class ReservationResponse(BaseModel):
    walk_in_plate: str | None = None
    walk_in_phone: str | None = None
    id: str
    parking_id: str
    status: str
    checked_in_at: str | None = None
    checked_out_at: str | None = None
    spot_code: str | None = None
    arrival_estimate_at: str | None = None
    is_manual_arrival: bool = False
    route_minutes: int
    hold_expires_at: str
    estimated_total: float
    spot_type: str
    pricing_plan: str
    duration_hours: int
    base_amount: float
    services_amount: float
    platform_fee_amount: float
    final_total: float
    selected_services: list[ReservationServiceSnapshot]
    platform_fees: list[ReservationPlatformFeeSnapshot]
    payment_status: str
    notification_status: str
    cancelled_at: str | None = None
    cancellation_fee_amount: float = 0
    cancellation_credit_amount: float = 0
    checkout_grace_minutes: int = 15
    checkout_excess_minutes: int = 0
    checkout_excess_amount: float = 0
    checkout_excess_paid_at: str | None = None
