from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.modules.auth.auth_service import AuthService
from app.modules.auth.schemas import PartnerSignupRequest
from app.modules.partners.models import PartnerProfile

router = APIRouter(prefix="/partners", tags=["Partners"])


@router.post("/signup")
async def partner_signup(
    data: PartnerSignupRequest,
    db: AsyncSession = Depends(get_db),
):
    user = await AuthService.register_partner(db, data)

    profile = PartnerProfile(
        tenant_id=user.tenant_id,
        service_type=data.service_type,
        company_name=data.company_name,
        cnpj=data.cnpj,
        registration_status=data.registration_status,
        responsible_name=data.responsible_name,
        has_insurance=data.has_insurance,
        insurance_provider=data.insurance_provider,
        instagram=data.instagram,
        website=data.website,
        social_links=data.social_links,
    )
    db.add(profile)
    await db.commit()

    return {
        "message": "Partner registered. Documents and inspection are required before publishing.",
        "tenant_id": user.tenant_id,
        "approval_status": profile.approval_status,
    }
