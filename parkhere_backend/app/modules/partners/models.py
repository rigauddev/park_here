from sqlalchemy import Boolean, Column, ForeignKey, String

from app.db.base import BaseModel


class PartnerProfile(BaseModel):
    __tablename__ = "partner_profiles"

    tenant_id = Column(String(36), ForeignKey("tenants.id"), nullable=False)
    service_type = Column(String(40), nullable=False)
    company_name = Column(String(255), nullable=False)
    cnpj = Column(String(20), nullable=False)
    document_type = Column(String(10), nullable=True)
    document_number = Column(String(20), nullable=True)
    registration_status = Column(String(80), nullable=False)
    responsible_name = Column(String(255), nullable=False)
    has_insurance = Column(Boolean, default=False)
    insurance_provider = Column(String(255), nullable=True)
    instagram = Column(String(255), nullable=True)
    website = Column(String(255), nullable=True)
    social_links = Column(String(500), nullable=True)
    approval_status = Column(String(40), nullable=False, default="waiting_documents")
