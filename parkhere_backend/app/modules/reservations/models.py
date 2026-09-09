from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String, Text

from app.db.base import BaseModel
from app.modules.customer_assets.models import Vehicle  # noqa: F401


class Reservation(BaseModel):
    __tablename__ = "reservations"

    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=False)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    walk_in_plate = Column(String(7), nullable=True)
    walk_in_phone = Column(String(20), nullable=True)
    vehicle_id = Column(String(36), ForeignKey("vehicles.id"), nullable=True)
    guide_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    guide_commission_amount = Column(Float, nullable=False, default=0)
    guide_platform_fee_amount = Column(Float, nullable=False, default=0)
    guide_payout_amount = Column(Float, nullable=False, default=0)
    status = Column(String(40), nullable=False, default="pre_reserved")
    checked_in_at = Column(DateTime(timezone=True), nullable=True)
    checked_out_at = Column(DateTime(timezone=True), nullable=True)
    route_minutes = Column(Integer, nullable=False, default=15)
    hold_expires_at = Column(DateTime(timezone=True), nullable=False)
    estimated_total = Column(Float, nullable=False, default=0)
    spot_type = Column(String(20), nullable=False, default="uncovered")
    pricing_plan = Column(String(20), nullable=False, default="hourly")
    duration_hours = Column(Integer, nullable=False, default=1)
    base_amount = Column(Float, nullable=False, default=0)
    services_amount = Column(Float, nullable=False, default=0)
    platform_fee_amount = Column(Float, nullable=False, default=0)
    final_total = Column(Float, nullable=False, default=0)
    selected_services_snapshot = Column(Text, nullable=True)
    platform_fee_snapshot = Column(Text, nullable=True)
    payment_status = Column(String(40), nullable=False, default="pending_checkin")
    notification_status = Column(String(40), nullable=False, default="sent_to_parking")
    spot_code = Column(String(20), nullable=True)
    arrival_estimate_at = Column(DateTime(timezone=True), nullable=True)
    is_manual_arrival = Column(Boolean, nullable=False, default=False)
    cancelled_at = Column(DateTime(timezone=True), nullable=True)
    cancelled_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    cancellation_reason = Column(Text, nullable=True)
    cancellation_fee_amount = Column(Float, nullable=False, default=0)
    cancellation_credit_amount = Column(Float, nullable=False, default=0)
    checkout_grace_minutes = Column(Integer, nullable=False, default=15)
    checkout_excess_minutes = Column(Integer, nullable=False, default=0)
    checkout_excess_amount = Column(Float, nullable=False, default=0)
    checkout_excess_paid_at = Column(DateTime(timezone=True), nullable=True)
