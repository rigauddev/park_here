from datetime import datetime
from typing import Any
from pydantic import BaseModel, ConfigDict, Field, field_validator

class RentalCompanyCreate(BaseModel):
    parent_parking_id: str | None = None
    parent_unit_id: str | None = None
    parent_service_type: str | None = Field(default=None, max_length=40)
    name: str = Field(min_length=2, max_length=120)
    address: str | None = Field(default=None, max_length=200)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    cnpj: str | None = Field(default=None, max_length=20)

class RentalCompanyOut(RentalCompanyCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    tenant_id: str
    is_active: bool
    service_type: str
    unit_kind: str

class VehicleCreate(BaseModel):
    company_id: str
    group_id: str | None = None
    vehicle_type: str = Field(default="car", pattern=r"^(car|suv|pickup|van|motorcycle|scooter|bicycle|bus|truck|motorhome|electric_car)$")
    model: str = Field(min_length=1, max_length=120)
    brand: str = Field(min_length=1, max_length=80)
    price_per_day: float = Field(gt=0)
    plate: str | None = Field(default=None, max_length=20)
    year: int | None = Field(default=None, ge=1950, le=2100)
    photo_urls: list[str] = Field(default_factory=list, max_length=8)
    specifications: dict[str, Any] = Field(default_factory=dict)

class VehicleOut(VehicleCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    status: str
    is_active: bool


class VehicleGroupCreate(BaseModel):
    company_id: str
    name: str = Field(min_length=2, max_length=120)
    code: str | None = Field(default=None, max_length=20)
    vehicle_type: str = Field(default='car', pattern=r'^(car|suv|pickup|van|motorcycle|scooter|bicycle|bus|truck|motorhome|electric_car)$')
    description: str | None = Field(default=None, max_length=2000)
    suggested_price_per_day: float | None = Field(default=None, gt=0)


class VehicleGroupOut(VehicleGroupCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    is_default: bool
    is_active: bool
    is_blocked: bool


class VehicleCatalogOut(BaseModel):
    make: str | None = None
    model: str | None = None
    year: int
    vehicle_type: str
    photo_urls: list[str] = Field(default_factory=list)
    specifications: dict[str, Any] = Field(default_factory=dict)


class RentalPlanCreate(BaseModel):
    company_id: str
    group_id: str | None = None
    name: str = Field(min_length=2, max_length=120)
    description: str | None = Field(default=None, max_length=2000)
    vehicle_type: str | None = Field(default=None, max_length=30)
    price_per_day: float = Field(gt=0)
    price_per_week: float | None = Field(default=None, gt=0)
    price_per_month: float | None = Field(default=None, gt=0)
    deposit_amount: float = Field(default=0, ge=0)
    included_items: list[str] = Field(default_factory=list, max_length=30)
    mileage_limit_per_day: int | None = Field(default=None, ge=0)


class RentalPlanOut(RentalPlanCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    is_active: bool

class ReservationCreate(BaseModel):
    company_id: str
    vehicle_id: str
    plan_id: str | None = None
    start_date: datetime
    end_date: datetime
    extras: dict[str, Any] | None = None
    km_start: int | None = Field(default=None, ge=0)

    @field_validator("end_date")
    @classmethod
    def valid_period(cls, value: datetime, info):
        start = info.data.get("start_date")
        if start and value <= start:
            raise ValueError("end_date must be after start_date")
        return value

class ReservationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    tenant_id: str
    user_id: str
    company_id: str
    vehicle_id: str
    plan_id: str | None = None
    start_date: datetime
    end_date: datetime
    total_price: float
    base_amount: float = 0
    customer_fee_amount: float = 0
    establishment_fee_amount: float = 0
    platform_fee_amount: float = 0
    final_total: float = 0
    platform_fee_snapshot: list[dict[str, Any]] = Field(default_factory=list)
    status: str
    payment_status: str = "pending"
    extras: dict[str, Any] | None = None
    km_start: int | None = None
    km_end: int | None = None
    created_at: datetime
    updated_at: datetime

class CheckinCreate(BaseModel):
    reservation_id: str
    km: int | None = Field(default=None, ge=0)
    photos: list[str] = Field(default_factory=list, max_length=8)
    items: dict[str, Any] | None = None
    notes: str | None = Field(default=None, max_length=1000)

class CheckoutCreate(CheckinCreate):
    damage_fine: float = Field(default=0, ge=0)


class MaintenanceCreate(BaseModel):
    vehicle_id: str
    maintenance_type: str = Field(min_length=2, max_length=40)
    description: str | None = Field(default=None, max_length=2000)
    performed_at: datetime
    next_due_at: datetime | None = None
    odometer: int | None = Field(default=None, ge=0)
    cost: float | None = Field(default=None, ge=0)
    status: str = Field(default="completed", pattern=r"^(scheduled|in_progress|completed|cancelled)$")


class MaintenanceOut(MaintenanceCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str


class RentalItemCreate(BaseModel):
    company_id: str
    name: str = Field(min_length=2, max_length=100)
    category: str = Field(default="accessory", min_length=2, max_length=40)
    description: str | None = Field(default=None, max_length=2000)


class RentalItemOut(RentalItemCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    is_active: bool


class RentalContractOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    reservation_id: str
    version: str
    terms_text: str
    status: str
    customer_accepted_at: datetime | None = None
    partner_accepted_at: datetime | None = None
    pdf_path: str | None = None


class ContractAccept(BaseModel):
    role: str = Field(pattern=r"^(customer|partner)$")


class FineCreate(BaseModel):
    reservation_id: str
    vehicle_id: str
    fine_type: str = Field(min_length=2, max_length=40)
    occurred_at: datetime
    amount: float = Field(gt=0)
    evidence_url: str | None = Field(default=None, max_length=500)
    notes: str | None = Field(default=None, max_length=2000)


class FineOut(FineCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    status: str
