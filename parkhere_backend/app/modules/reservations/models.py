from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String

from app.db.base import BaseModel
from app.modules.customer_assets.models import Vehicle  # noqa: F401


class Reservation(BaseModel):
    __tablename__ = "reservations"

    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=False)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    vehicle_id = Column(String(36), ForeignKey("vehicles.id"), nullable=True)
    status = Column(String(40), nullable=False, default="pre_reserved")
    route_minutes = Column(Integer, nullable=False, default=15)
    hold_expires_at = Column(DateTime(timezone=True), nullable=False)
    estimated_total = Column(Float, nullable=False, default=0)
    payment_status = Column(String(40), nullable=False, default="pending_checkin")
    notification_status = Column(String(40), nullable=False, default="sent_to_parking")
