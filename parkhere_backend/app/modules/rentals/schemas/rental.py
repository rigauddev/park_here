from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class RentalCompanyBase(BaseModel):
    name: str = Field(..., max_length=120)
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    cnpj: Optional[str] = None

class RentalCompanyCreate(RentalCompanyBase):
    pass

class RentalCompanyOut(RentalCompanyBase):
    id: str
    is_active: bool

    class Config:
        orm_mode = True

class VehicleBase(BaseModel):
    model: str = Field(..., max_length=120)
    brand: str = Field(..., max_length=80)
    price_per_day: float
    status: str = Field(default="available")
    plate: Optional[str] = None
    year: Optional[int] = None

class VehicleCreate(VehicleBase):
    company_id: str

class VehicleOut(VehicleBase):
    id: str
    company_id: str

    class Config:
        orm_mode = True

class ReservationBase(BaseModel):
    partner_id: str
    company_id: str
    vehicle_id: str
    start_date: datetime
    end_date: datetime
    extras: Optional[dict] = None
    km_start: Optional[int] = None

class ReservationCreate(ReservationBase):
    pass

class ReservationOut(ReservationBase):
    id: str
    total_price: float
    status: str
    km_end: Optional[int] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True

class CheckinBase(BaseModel):
    reservation_id: str
    km: Optional[int] = None
    photos: Optional[List[str]] = None
    items: Optional[dict] = None
    notes: Optional[str] = None

class CheckinCreate(CheckinBase):
    pass

class CheckoutBase(BaseModel):
    reservation_id: str
    km: Optional[int] = None
    photos: Optional[List[str]] = None
    items: Optional[dict] = None
    notes: Optional[str] = None
    damage_fine: Optional[float] = 0.0

class CheckoutCreate(CheckoutBase):
    pass
