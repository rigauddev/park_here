from pydantic import BaseModel, Field


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
    spot_type: str = "uncovered"
    pricing_plan: str = "hourly"
    duration_hours: int = 1
    service_codes: list[str] = Field(default_factory=list)


class CancelReservationRequest(BaseModel):
    reason: str | None = None


class ReservationResponse(BaseModel):
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
