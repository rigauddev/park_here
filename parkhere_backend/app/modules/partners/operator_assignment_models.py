from sqlalchemy import Column, DateTime, ForeignKey, String, UniqueConstraint
from app.db.base import BaseModel


class OperatorParkingAssignment(BaseModel):
    __tablename__ = "operator_parking_assignments"
    __table_args__ = (UniqueConstraint("operator_id", "parking_id"),)
    operator_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=False)


class OperatorWorkShift(BaseModel):
    __tablename__ = "operator_work_shifts"
    operator_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=False)
    starts_at = Column(DateTime, nullable=False)
    ends_at = Column(DateTime, nullable=False)
