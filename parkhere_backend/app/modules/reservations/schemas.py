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
    spot_type: str = "uncovered"
    pricing_plan: str = "hourly"
    duration_hours: int = 1
    service_codes: list[str] = Field(default_factory=list)


class ReservationResponse(BaseModel):
    id: str
    parking_id: str
    status: str
    checked_in_at: str | None = None
    checked_out_at: str | None = None
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
