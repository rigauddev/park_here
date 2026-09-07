from sqlalchemy import Column, ForeignKey, String, Text, UniqueConstraint

from app.db.base import BaseModel


class GuideParkingLink(BaseModel):
    __tablename__ = 'guide_parking_links'
    __table_args__ = (UniqueConstraint('guide_user_id', 'parking_id'),)

    guide_user_id = Column(String(36), ForeignKey('users.id'), nullable=False)
    parking_id = Column(String(36), ForeignKey('parkings.id'), nullable=False)
    status = Column(String(20), nullable=False, default='pending')
    commission_type = Column(String(20), nullable=True)
    commission_value = Column(String(30), nullable=True)
    # JSON text keeps the contract portable across MySQL and SQLite. Keys are
    # daily, weekly, monthly and long_term, each with type/value.
    commission_terms = Column(Text, nullable=True)


class GuideReview(BaseModel):
    __tablename__ = 'guide_reviews'
    __table_args__ = (UniqueConstraint('reservation_id'),)

    guide_user_id = Column(String(36), ForeignKey('users.id'), nullable=False)
    reservation_id = Column(String(36), ForeignKey('reservations.id'), nullable=False)
    customer_user_id = Column(String(36), ForeignKey('users.id'), nullable=False)
    rating = Column(String(10), nullable=False)
    comment = Column(Text, nullable=True)
