import json
from collections import defaultdict
from datetime import date, datetime, time, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.parkings.models import Parking, ParkingService
from app.modules.parkings.convenience_models import ParkingConvenienceProduct
from app.modules.partners.models import PartnerProfile
from app.modules.partners.operator_assignment_models import OperatorWorkShift
from app.modules.platform_fees.feature_catalog import feature_by_key
from app.modules.platform_fees.models import PartnerFeatureEntitlement
from app.modules.reservations.models import Reservation
from app.modules.users.models.user_model import User
from app.modules.users.models.user_model_role_enum import UserRoleEnum


router = APIRouter(prefix="/partners/dashboard", tags=["Partner dashboard"])


def _ensure_partner(user: User) -> None:
    if user.role not in {
        UserRoleEnum.PARTNER_MANAGER,
        UserRoleEnum.PARKING_ADMIN,
        UserRoleEnum.OPERATOR,
    } or not user.tenant_id:
        raise HTTPException(status_code=403, detail="Partner access required")


async def _ensure_dashboard_feature(
    db: AsyncSession, user: User, profile: PartnerProfile
) -> None:
    feature = feature_by_key(profile.service_type, "dashboard")
    entitlement = await db.scalar(select(PartnerFeatureEntitlement).where(
        PartnerFeatureEntitlement.tenant_id == user.tenant_id,
        PartnerFeatureEntitlement.feature_key == "dashboard",
    ))
    enabled = entitlement.is_enabled if entitlement else bool(feature and feature["default_is_enabled"])
    if entitlement and entitlement.expires_at:
        expiry = entitlement.expires_at
        if expiry.tzinfo is None:
            expiry = expiry.replace(tzinfo=timezone.utc)
        enabled = enabled and expiry > datetime.now(timezone.utc)
    if not enabled:
        raise HTTPException(status_code=403, detail={
            "code": "feature_locked",
            "feature_key": "dashboard",
            "name": feature["name"] if feature else "Dashboard",
            "is_paid": entitlement.is_paid if entitlement else bool(feature and feature["default_is_paid"]),
            "price": entitlement.price if entitlement else 0,
            "billing_period": entitlement.billing_period if entitlement else "monthly",
        })


@router.get("")
async def partner_dashboard(
    start: date | None = Query(default=None, description="First day, YYYY-MM-DD"),
    end: date | None = Query(default=None, description="Last day, YYYY-MM-DD"),
    parking_id: str | None = None,
    service_type: str | None = Query(default=None, pattern="^(parking|guide|hotel|all)$"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return the partner dashboard in one payload.

    The aggregation is intentionally scoped to the authenticated tenant. Unit
    separation is deterministic: the oldest active unit is the matriz and the
    remaining units are filiais until an explicit unit hierarchy is introduced.
    """
    _ensure_partner(current_user)
    profile = await db.scalar(
        select(PartnerProfile).where(PartnerProfile.tenant_id == current_user.tenant_id)
    )
    if profile is None:
        raise HTTPException(status_code=404, detail="Partner profile not found")
    await _ensure_dashboard_feature(db, current_user, profile)

    today = datetime.now(timezone.utc).date()
    first_day = start or (today - timedelta(days=29))
    last_day = end or today
    if last_day < first_day:
        raise HTTPException(status_code=422, detail="end must be on or after start")
    from_dt = datetime.combine(first_day, time.min, tzinfo=timezone.utc)
    until_dt = datetime.combine(last_day + timedelta(days=1), time.min, tzinfo=timezone.utc)

    parking_query = select(Parking).where(
        Parking.tenant_id == current_user.tenant_id,
        Parking.is_active.is_(True),
    ).order_by(Parking.created_at.asc())
    if parking_id:
        parking_query = parking_query.where(Parking.id == parking_id)
    parkings = list((await db.scalars(parking_query)).all())
    allowed_ids = {parking.id for parking in parkings}
    convenience_rows = list((await db.scalars(
        select(ParkingConvenienceProduct).where(
            ParkingConvenienceProduct.parking_id.in_(allowed_ids or {"__none__"}),
            ParkingConvenienceProduct.is_active.is_(True),
        )
    )).all())
    convenience_categories: dict[str, int] = defaultdict(int)
    for product in convenience_rows:
        convenience_categories[product.category] += 1

    reservation_query = (
        select(Reservation, Parking, User)
        .join(Parking, Parking.id == Reservation.parking_id)
        .outerjoin(User, User.id == Reservation.user_id)
        .where(
            Parking.tenant_id == current_user.tenant_id,
            Reservation.created_at >= from_dt,
            Reservation.created_at < until_dt,
        )
        .order_by(Reservation.created_at.asc())
    )
    if allowed_ids:
        reservation_query = reservation_query.where(Reservation.parking_id.in_(allowed_ids))
    else:
        reservation_query = reservation_query.where(Reservation.parking_id == "__none__")
    rows = list((await db.execute(reservation_query)).all())

    by_unit: dict[str, dict] = {
        parking.id: {
            "id": parking.id,
            "name": parking.name,
            "city": parking.city,
            "unit_type": "matriz" if index == 0 else "filial",
            "is_active": bool(parking.is_active),
            "available_spots": parking.available_spots,
            "total_spots": parking.total_spots,
            "reservations": 0,
            "paid_revenue": 0.0,
            "average_ticket": 0.0,
        }
        for index, parking in enumerate(parkings)
    }
    modality: dict[str, dict[str, float | int]] = defaultdict(
        lambda: {"reservations": 0, "revenue": 0.0}
    )
    service_breakdown: dict[str, dict[str, float | int]] = {
        "parking": {"reservations": 0, "revenue": 0.0},
        "guide": {"reservations": 0, "revenue": 0.0},
        "hotel": {"reservations": 0, "revenue": 0.0},
    }
    city_counts: dict[str, int] = defaultdict(int)
    extra_services: dict[str, dict[str, str | float | int]] = {}
    for parking in parkings:
        service_rows = list((await db.scalars(select(ParkingService).where(
            ParkingService.parking_id == parking.id,
            ParkingService.is_active.is_(True),
        ))).all())
        for service in service_rows:
            extra_services.setdefault(service.code, {
                "code": service.code,
                "name": service.name,
                "description": service.description or "",
                "reservations": 0,
                "revenue": 0.0,
            })
    monthly: dict[str, dict[str, float | int]] = defaultdict(
        lambda: {"reservations": 0, "revenue": 0.0}
    )

    for reservation, parking, customer in rows:
        unit = by_unit.get(parking.id)
        if unit is None:
            continue
        reservation_service = "guide" if reservation.guide_user_id else "parking"
        if service_type and service_type != "all" and service_type != reservation_service:
            continue
        paid_amount = float(reservation.final_total or 0) if reservation.payment_status == "paid" else 0.0
        unit["reservations"] += 1
        unit["paid_revenue"] += paid_amount
        plan = reservation.pricing_plan or "hourly"
        modality[plan]["reservations"] += 1
        modality[plan]["revenue"] += paid_amount
        service_breakdown[reservation_service]["reservations"] += 1
        service_breakdown[reservation_service]["revenue"] += paid_amount
        if reservation.selected_services_snapshot:
            try:
                selected_services = json.loads(reservation.selected_services_snapshot)
            except (TypeError, ValueError):
                selected_services = []
            for selected in selected_services:
                code = selected.get("code") if isinstance(selected, dict) else None
                if code not in extra_services:
                    continue
                extra_services[code]["reservations"] += 1
                extra_services[code]["revenue"] += float(selected.get("price") or 0)
        if reservation.guide_user_id:
            service_breakdown["guide"]["reservations"] += 1
            service_breakdown["guide"]["revenue"] += paid_amount
        if customer and getattr(customer, "city", None):
            city_counts[customer.city] += 1
        month_key = reservation.created_at.strftime("%Y-%m")
        monthly[month_key]["reservations"] += 1
        monthly[month_key]["revenue"] += paid_amount

    for unit in by_unit.values():
        if unit["reservations"]:
            unit["average_ticket"] = round(
                unit["paid_revenue"] / unit["reservations"], 2
            )

    operator_rows = list((await db.scalars(select(User).where(
        User.tenant_id == current_user.tenant_id,
        User.role == UserRoleEnum.OPERATOR,
        User.deleted_at.is_(None),
    ))).all())
    staffing = []
    for parking in parkings:
        shifts = list((await db.scalars(select(OperatorWorkShift).where(
            OperatorWorkShift.parking_id == parking.id,
            OperatorWorkShift.starts_at < until_dt,
            OperatorWorkShift.ends_at >= from_dt,
        ))).all())
        staffing.append({
            "parking_id": parking.id,
            "parking_name": parking.name,
            "operators": len({shift.operator_id for shift in shifts if shift.operator_id}),
            "shifts": len(shifts),
            "unassigned_shifts": sum(1 for shift in shifts if shift.operator_id is None),
        })

    total_paid = sum(float(item["paid_revenue"]) for item in by_unit.values())
    total_reservations = sum(int(item["reservations"]) for item in by_unit.values())
    return {
        "period": {"start": first_day.isoformat(), "end": last_day.isoformat()},
        "partner": {
            "tenant_id": current_user.tenant_id,
            "name": profile.company_name,
            "service_type": profile.service_type,
        },
        "summary": {
            "reservations": total_reservations,
            "paid_revenue": round(total_paid, 2),
            "average_ticket": round(total_paid / total_reservations, 2) if total_reservations else 0.0,
            "active_units": len(parkings),
            "operators": len(operator_rows),
            "active_convenience_products": len(convenience_rows),
        },
        "units": list(by_unit.values()),
        "service_breakdown": service_breakdown,
        "additional_services": list(extra_services.values()),
        "convenience": {
            "products": len(convenience_rows),
            "categories": [
                {"category": category, "products": count}
                for category, count in sorted(convenience_categories.items())
            ],
        },
        "modality_breakdown": dict(modality),
        "monthly": [
            {"month": key, **value} for key, value in sorted(monthly.items())
        ],
        "customer_cities": [
            {"city": city, "reservations": count}
            for city, count in sorted(city_counts.items(), key=lambda item: item[1], reverse=True)
        ],
        "staffing": staffing,
        "filters": {
            "parking_id": parking_id,
            "service_type": service_type or "all",
        },
        "notes": [
            "Valores pagos consideram somente transações com status paid.",
            "A matriz é a unidade ativa mais antiga; filiais são as demais unidades.",
            "Cidades de origem serão preenchidas quando o cadastro do cliente possuir cidade.",
        ],
    }
