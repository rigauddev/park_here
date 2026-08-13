from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey
from sqlalchemy.sql import func
from app.db.base import BaseModel

class MFAChallenge(BaseModel):
    __tablename__ = "mfa_challenges"

    user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    code = Column(String(6), nullable=False)
    expires_at = Column(DateTime, nullable=False)
    is_used = Column(Boolean, default=False)