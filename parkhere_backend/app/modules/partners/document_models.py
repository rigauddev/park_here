from sqlalchemy import Column, ForeignKey, String

from app.db.base import BaseModel


class PartnerDocument(BaseModel):
    __tablename__ = 'partner_documents'

    tenant_id = Column(String(36), ForeignKey('tenants.id'), nullable=False)
    document_type = Column(String(20), nullable=False)
    file_name = Column(String(255), nullable=False)
    storage_path = Column(String(500), nullable=False)
