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
    vehicle_type: str = Field(default="car", pattern=r"^(car|suv|pickup|van|motorcycle|scooter|bicycle|bus|truck|motorhome|electric_car)$")
    model: str = Field(min_length=1, max_length=120)
    brand: str = Field(min_length=1, max_length=80)
    price_per_day: float = Field(gt=0)
    plate: str | None = Field(default=None, max_length=20)
    year: int | None = Field(default=None, ge=1950, le=2100)

class VehicleOut(VehicleCreate):
    model_config = ConfigDict(from_attributes=True)
    id: str
    status: str
    is_active: bool

class ReservationCreate(BaseModel):
    company_id: str
    vehicle_id: str
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
    start_date: datetime
    end_date: datetime
    total_price: float
    status: str
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
