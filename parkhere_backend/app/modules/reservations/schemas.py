from pydantic import BaseModel


class PreCheckinReservationRequest(BaseModel):
    parking_id: str
    route_minutes: int
    estimated_total: float
    vehicle_id: str | None = None


class ReservationResponse(BaseModel):
    id: str
    parking_id: str
    status: str
    route_minutes: int
    hold_expires_at: str
    estimated_total: float
    payment_status: str
    notification_status: str
