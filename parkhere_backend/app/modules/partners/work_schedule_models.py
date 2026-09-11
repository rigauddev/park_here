import json
from sqlalchemy import Column, DateTime, ForeignKey, Integer, Float, String, Text
from app.db.base import BaseModel


class OperatorWorkProfile(BaseModel):
    __tablename__ = "operator_work_profiles"
    operator_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=False)
    daily_hours = Column(Float, nullable=False, default=8)
    lunch_minutes = Column(Integer, nullable=False, default=60)
    days_off = Column(Text, nullable=False, default="[]")
    work_modality = Column(String(20), nullable=False, default="8h")
    bank_hours = Column(Float, nullable=False, default=0)

    def days_off_list(self):
        try:
            return json.loads(self.days_off or "[]")
        except json.JSONDecodeError:
            return []


class OperatorScheduleHistory(BaseModel):
    __tablename__ = "operator_schedule_history"
    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=False)
    changed_by = Column(String(36), ForeignKey("users.id"), nullable=False)
    action = Column(String(40), nullable=False)
    details = Column(Text, nullable=False, default="{}")
