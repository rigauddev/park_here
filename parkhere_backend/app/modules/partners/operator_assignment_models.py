from sqlalchemy import Column, DateTime, ForeignKey, String, UniqueConstraint
from app.db.base import BaseModel


class OperatorParkingAssignment(BaseModel):
    __tablename__ = "operator_parking_assignments"
    __table_args__ = (UniqueConstraint("operator_id", "parking_id"),)
    operator_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=False)


class OperatorWorkShift(BaseModel):
    __tablename__ = "operator_work_shifts"
    operator_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    # Legacy parking_id remains supported; rental shifts identify the unit by
    # rental_company_id and service_type.
    parking_id = Column(String(36), ForeignKey("parkings.id"), nullable=True)
    rental_company_id = Column(String(36), ForeignKey("rental_companies.id"), nullable=True)
    service_type = Column(String(40), nullable=False, default="parking")
    starts_at = Column(DateTime, nullable=False)
    ends_at = Column(DateTime, nullable=False)
