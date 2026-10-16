from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.parkings.convenience_models import ParkingConvenienceProduct
from app.modules.parkings.models import Parking
from app.modules.users.models.user_model import User
from app.modules.users.models.user_model_role_enum import UserRoleEnum

router = APIRouter(prefix="/partners/parking-management", tags=["Parking conveniences"])


class ConvenienceProductInput(BaseModel):
    category: str = Field(min_length=1, max_length=80)
    subcategory: str | None = Field(default=None, max_length=80)
    name: str = Field(min_length=1, max_length=160)
    description: str | None = Field(default=None, max_length=500)
    price: float = Field(ge=0, allow_inf_nan=False)
    is_active: bool = True

    @field_validator("category", "subcategory", "name", "description", mode="before")
    @classmethod
    def strip_text(cls, value):
        return value.strip() if isinstance(value, str) else value


def _payload(item: ParkingConvenienceProduct) -> dict:
    return {
        "id": item.id,
        "parking_id": item.parking_id,
        "category": item.category,
        "subcategory": item.subcategory,
        "name": item.name,
        "description": item.description,
        "price": item.price,
        "is_active": item.is_active,
    }


async def _unit(db: AsyncSession, parking_id: str, user: User) -> Parking:
    if user.role not in {
        UserRoleEnum.PARTNER_MANAGER,
        UserRoleEnum.PARKING_ADMIN,
        UserRoleEnum.OPERATOR,
    }:
        raise HTTPException(status_code=403, detail="Acesso restrito ao parceiro")
    parking = await db.scalar(
        select(Parking).where(Parking.id == parking_id, Parking.tenant_id == user.tenant_id)
    )
    if parking is None:
        raise HTTPException(status_code=404, detail="Unidade não encontrada")
    return parking


@router.get("/{parking_id}/conveniences")
async def list_conveniences(
    parking_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _unit(db, parking_id, current_user)
    items = await db.scalars(
        select(ParkingConvenienceProduct)
        .where(ParkingConvenienceProduct.parking_id == parking_id)
        .order_by(ParkingConvenienceProduct.category, ParkingConvenienceProduct.name)
    )
    return [_payload(item) for item in items.all()]


@router.post("/{parking_id}/conveniences", status_code=201)
async def create_convenience(
    parking_id: str,
    data: ConvenienceProductInput,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _unit(db, parking_id, current_user)
    if current_user.role == UserRoleEnum.OPERATOR:
        raise HTTPException(status_code=403, detail="Somente o gestor pode cadastrar produtos")
    item = ParkingConvenienceProduct(parking_id=parking_id, **data.model_dump())
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return _payload(item)


@router.put("/{parking_id}/conveniences/{product_id}")
async def update_convenience(
    parking_id: str,
    product_id: str,
    data: ConvenienceProductInput,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _unit(db, parking_id, current_user)
    if current_user.role == UserRoleEnum.OPERATOR:
        raise HTTPException(status_code=403, detail="Somente o gestor pode editar produtos")
    item = await db.scalar(
        select(ParkingConvenienceProduct).where(
            ParkingConvenienceProduct.id == product_id,
            ParkingConvenienceProduct.parking_id == parking_id,
        )
    )
    if item is None:
        raise HTTPException(status_code=404, detail="Produto não encontrado")
    for key, value in data.model_dump().items():
        setattr(item, key, value)
    await db.commit()
    await db.refresh(item)
    return _payload(item)


@router.delete("/{parking_id}/conveniences/{product_id}", status_code=204)
async def deactivate_convenience(
    parking_id: str,
    product_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _unit(db, parking_id, current_user)
    if current_user.role == UserRoleEnum.OPERATOR:
        raise HTTPException(status_code=403, detail="Somente o gestor pode desativar produtos")
    item = await db.scalar(
        select(ParkingConvenienceProduct).where(
            ParkingConvenienceProduct.id == product_id,
            ParkingConvenienceProduct.parking_id == parking_id,
        )
    )
    if item is None:
        raise HTTPException(status_code=404, detail="Produto não encontrado")
    item.is_active = False
    await db.commit()
