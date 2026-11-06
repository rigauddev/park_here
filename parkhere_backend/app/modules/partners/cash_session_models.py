from sqlalchemy import Column, DateTime, Float, ForeignKey, String, Text

from app.db.base import BaseModel


class PartnerCashSession(BaseModel):
    """Single operator shift with separate parking and convenience ledgers."""
    __tablename__ = "partner_cash_sessions"

    operator_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=False, index=True)
    status = Column(String(20), nullable=False, default="open")
    opened_at = Column(DateTime(timezone=True), nullable=False)
    closed_at = Column(DateTime(timezone=True), nullable=True)
    parking_opening_cash = Column(Float, nullable=False, default=0)
    convenience_opening_cash = Column(Float, nullable=False, default=0)
    parking_closing_cash = Column(Float, nullable=True)
    convenience_closing_cash = Column(Float, nullable=True)
    closing_notes = Column(String(500), nullable=True)


class PartnerCashBleed(BaseModel):
    """Cash bleed / withdrawal from an open shift or pos register."""
    __tablename__ = "partner_cash_bleeds"

    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False, index=True)
    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=False, index=True)
    cash_session_id = Column(String(36), nullable=True)
    operator_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    operator_name = Column(String(120), nullable=False)
    target_type = Column(String(30), nullable=False, default="convenience")  # convenience | parking
    amount = Column(Float, nullable=False)
    reason = Column(String(255), nullable=False)
    notes = Column(Text, nullable=True)
