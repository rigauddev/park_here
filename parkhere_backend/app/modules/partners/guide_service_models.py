from sqlalchemy import Boolean, Column, ForeignKey, Float, String, Text

from app.db.base import BaseModel


class GuideService(BaseModel):
    __tablename__ = 'guide_services'

    guide_user_id = Column(String(36), ForeignKey('users.id'), nullable=False)
    name = Column(String(160), nullable=False)
    description = Column(Text, nullable=True)
    price = Column(Float, nullable=False, default=0)
    duration_minutes = Column(String(20), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
