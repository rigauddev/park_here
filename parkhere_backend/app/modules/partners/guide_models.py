from sqlalchemy import Column, ForeignKey, String, UniqueConstraint

from app.db.base import BaseModel


class GuideParkingLink(BaseModel):
    __tablename__ = 'guide_parking_links'
    __table_args__ = (UniqueConstraint('guide_user_id', 'parking_id'),)

    guide_user_id = Column(String(36), ForeignKey('users.id'), nullable=False)
    parking_id = Column(String(36), ForeignKey('parkings.id'), nullable=False)
    status = Column(String(20), nullable=False, default='pending')
