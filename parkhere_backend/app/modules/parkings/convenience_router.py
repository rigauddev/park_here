from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.parkings.convenience_models import (
    ParkingConvenienceCategory,
    ParkingConvenienceProduct,
    ParkingConvenienceSale,
    ParkingConvenienceSaleItem,
)
from app.modules.parkings.models import Parking
from app.modules.users.models.user_model import User
from app.modules.users.models.user_model_role_enum import UserRoleEnum
from app.modules.partners.models import PartnerProfile
from app.modules.platform_fees.models import PartnerFeatureEntitlement
from app.modules.platform_fees.feature_catalog import feature_by_key

router = APIRouter(prefix="/partners/parking-management", tags=["Parking conveniences"])


class ConvenienceProductInput(BaseModel):
    category_id: str | None = None
    category: str = Field(min_length=1, max_length=80)
    subcategory: str | None = Field(default=None, max_length=80)
    name: str = Field(min_length=1, max_length=160)
    description: str | None = Field(default=None, max_length=500)
    price: float = Field(ge=0, allow_inf_nan=False)
    barcode: str | None = Field(default=None, max_length=80)
    stock_quantity: int | None = Field(default=None, ge=0, le=2_000_000)
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
        "category_id": item.category_id,
        "subcategory": item.subcategory,
        "name": item.name,
        "description": item.description,
        "price": item.price,
        "barcode": item.barcode,
        "stock_quantity": item.stock_quantity,
        "is_active": item.is_active,
    }


class ConvenienceCategoryInput(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    subcategory: str | None = Field(default=None, max_length=80)


class SaleItemInput(BaseModel):
    product_id: str
    quantity: int = Field(ge=1, le=999)


class ConvenienceSaleInput(BaseModel):
    items: list[SaleItemInput] = Field(min_length=1)
    payment_method: str = "cash"
    cash_received: float | None = Field(default=None, ge=0, allow_inf_nan=False)


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


async def _ensure_access(db: AsyncSession, user: User, *, mutate: bool = False) -> None:
    profile = await db.scalar(select(PartnerProfile).where(PartnerProfile.tenant_id == user.tenant_id))
    feature = feature_by_key(profile.service_type if profile else None, 'convenience_management')
    entitlement = await db.scalar(select(PartnerFeatureEntitlement).where(
        PartnerFeatureEntitlement.tenant_id == user.tenant_id,
        PartnerFeatureEntitlement.feature_key == 'convenience_management',
    ))
    enabled = entitlement.is_enabled if entitlement else (feature or {}).get('default_is_enabled', False)
    if not enabled:
        raise HTTPException(status_code=403, detail={
            'code': 'feature_locked',
            'feature_key': 'convenience_management',
            'message': 'O módulo de conveniências precisa ser contratado e liberado.',
        })
    if mutate and user.role == UserRoleEnum.OPERATOR:
        raise HTTPException(status_code=403, detail='Somente o gestor pode alterar conveniências')


@router.get("/{parking_id}/conveniences")
async def list_conveniences(
    parking_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _unit(db, parking_id, current_user)
    await _ensure_access(db, current_user)
    items = await db.scalars(
        select(ParkingConvenienceProduct)
        .where(ParkingConvenienceProduct.parking_id == parking_id)
        .order_by(ParkingConvenienceProduct.category, ParkingConvenienceProduct.name)
    )
    return [_payload(item) for item in items.all()]


@router.get("/{parking_id}/convenience-categories")
async def list_convenience_categories(
    parking_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _unit(db, parking_id, current_user)
    await _ensure_access(db, current_user)
    rows = await db.scalars(select(ParkingConvenienceCategory).where(
        ParkingConvenienceCategory.tenant_id == current_user.tenant_id,
        ParkingConvenienceCategory.is_active.is_(True),
    ).order_by(ParkingConvenienceCategory.name, ParkingConvenienceCategory.subcategory))
    return [{"id": row.id, "name": row.name, "subcategory": row.subcategory} for row in rows.all()]


@router.post("/{parking_id}/convenience-categories", status_code=201)
async def create_convenience_category(
    parking_id: str,
    data: ConvenienceCategoryInput,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _unit(db, parking_id, current_user)
    await _ensure_access(db, current_user, mutate=True)
    existing = await db.scalar(select(ParkingConvenienceCategory).where(
        ParkingConvenienceCategory.tenant_id == current_user.tenant_id,
        ParkingConvenienceCategory.name == data.name.strip(),
        ParkingConvenienceCategory.subcategory == (data.subcategory.strip() if data.subcategory else None),
        ParkingConvenienceCategory.is_active.is_(True),
    ))
    if existing is not None:
        return {"id": existing.id, "name": existing.name, "subcategory": existing.subcategory}
    row = ParkingConvenienceCategory(
        tenant_id=current_user.tenant_id,
        name=data.name.strip(),
        subcategory=data.subcategory.strip() if data.subcategory else None,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return {"id": row.id, "name": row.name, "subcategory": row.subcategory}


@router.post("/{parking_id}/convenience-sales", status_code=201)
async def create_convenience_sale(
    parking_id: str,
    data: ConvenienceSaleInput,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _unit(db, parking_id, current_user)
    await _ensure_access(db, current_user)
    if data.payment_method not in {"cash", "pix", "credit_card", "debit_card"}:
        raise HTTPException(status_code=422, detail="Forma de pagamento inválida")
    product_ids = [item.product_id for item in data.items]
    products = (await db.scalars(select(ParkingConvenienceProduct).where(
        ParkingConvenienceProduct.id.in_(product_ids),
        ParkingConvenienceProduct.parking_id == parking_id,
        ParkingConvenienceProduct.is_active.is_(True),
    ))).all()
    by_id = {product.id: product for product in products}
    if len(by_id) != len(set(product_ids)):
        raise HTTPException(status_code=404, detail="Produto não encontrado ou inativo")
    total = 0.0
    sale_items: list[ParkingConvenienceSaleItem] = []
    for item in data.items:
        product = by_id[item.product_id]
        if product.stock_quantity is not None and product.stock_quantity < item.quantity:
            raise HTTPException(status_code=409, detail=f"Estoque insuficiente para {product.name}")
        line_total = round(float(product.price) * item.quantity, 2)
        total += line_total
        sale_items.append(ParkingConvenienceSaleItem(
            product_id=product.id,
            quantity=item.quantity,
            unit_price=product.price,
            total_price=line_total,
        ))
    cash_received = data.cash_received
    if data.payment_method == "cash" and (cash_received is None or cash_received < total):
        raise HTTPException(status_code=422, detail="Informe dinheiro recebido suficiente para a venda")
    change = round((cash_received or 0) - total, 2) if data.payment_method == "cash" else 0
    sale = ParkingConvenienceSale(
        tenant_id=current_user.tenant_id,
        parking_id=parking_id,
        operator_id=current_user.id,
        payment_method=data.payment_method,
        total_amount=round(total, 2),
        cash_received=cash_received,
        change_amount=change,
    )
    db.add(sale)
    await db.flush()
    for item in sale_items:
        item.sale_id = sale.id
        db.add(item)
    for item in data.items:
        product = by_id[item.product_id]
        if product.stock_quantity is not None:
            product.stock_quantity -= item.quantity
    await db.commit()
    # Server defaults such as created_at may be expired after commit in
    # async SQLAlchemy. Refresh before reading them for the receipt to avoid
    # a MissingGreenlet lazy load.
    await db.refresh(sale)
    return {
        "id": sale.id,
        "total_amount": sale.total_amount,
        "payment_method": sale.payment_method,
        "cash_received": sale.cash_received,
        "change_amount": sale.change_amount,
        "receipt": {
            "number": sale.id,
            "issued_at": sale.created_at.isoformat() if sale.created_at else None,
            "is_fiscal": False,
        },
        "items": [{"product_id": item.product_id, "quantity": item.quantity} for item in sale_items],
    }


@router.post("/{parking_id}/conveniences", status_code=201)
async def create_convenience(
    parking_id: str,
    data: ConvenienceProductInput,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _unit(db, parking_id, current_user)
    await _ensure_access(db, current_user, mutate=True)
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
    await _ensure_access(db, current_user, mutate=True)
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
    await _ensure_access(db, current_user, mutate=True)
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
