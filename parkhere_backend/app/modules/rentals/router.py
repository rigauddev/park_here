from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.core.dependencies import get_db
from .schemas.rental import (
    RentalCompanyCreate,
    RentalCompanyOut,
    VehicleCreate,
    VehicleOut,
    ReservationCreate,
    ReservationOut,
    CheckinCreate,
    CheckoutCreate,
)
from .services.rental_service import RentalService

router = APIRouter(prefix="/rentals", tags=["rentals"])

# Companies ----------------------------------------------------------
@router.get("/companies", response_model=List[RentalCompanyOut])
def list_companies(db: Session = Depends(get_db)):
    service = RentalService(db)
    return service.list_companies()

@router.post("/companies", response_model=RentalCompanyOut)
def create_company(payload: RentalCompanyCreate, db: Session = Depends(get_db)):
    service = RentalService(db)
    company = RentalCompany(**payload.dict())
    db.add(company)
    db.commit()
    db.refresh(company)
    return company

# Vehicles -----------------------------------------------------------
@router.get("/companies/{company_id}/vehicles", response_model=List[VehicleOut])
def list_vehicles(company_id: str, db: Session = Depends(get_db)):
    service = RentalService(db)
    return service.list_vehicles(company_id)

@router.post("/vehicles", response_model=VehicleOut)
def create_vehicle(payload: VehicleCreate, db: Session = Depends(get_db)):
    service = RentalService(db)
    vehicle = Vehicle(**payload.dict())
    db.add(vehicle)
    db.commit()
    db.refresh(vehicle)
    return vehicle

# Reservations -------------------------------------------------------
@router.post("/reservations", response_model=ReservationOut)
def create_reservation(payload: ReservationCreate, db: Session = Depends(get_db)):
    service = RentalService(db)
    reservation = service.create_reservation(
        partner_id=payload.partner_id,
        company_id=payload.company_id,
        vehicle_id=payload.vehicle_id,
        start_date=payload.start_date,
        end_date=payload.end_date,
        extras=payload.extras,
        km_start=payload.km_start,
    )
    return reservation

@router.get("/reservations/{reservation_id}", response_model=ReservationOut)
def get_reservation(reservation_id: str, db: Session = Depends(get_db)):
    service = RentalService(db)
    reservation = service.get_reservation(reservation_id)
    if not reservation:
        raise HTTPException(status_code=404, detail="Reservation not found")
    return reservation

# Check‑in ----------------------------------------------------------
@router.post("/checkin", response_model=dict)
def register_checkin(payload: CheckinCreate, db: Session = Depends(get_db)):
    service = RentalService(db)
    checkin = service.register_checkin(
        reservation_id=payload.reservation_id,
        km=payload.km,
        photos=payload.photos,
        items=payload.items,
        notes=payload.notes,
    )
    return {"id": checkin.id, "status": "checked_in"}

# Checkout ----------------------------------------------------------
@router.post("/checkout", response_model=dict)
def register_checkout(payload: CheckoutCreate, db: Session = Depends(get_db)):
    service = RentalService(db)
    checkout = service.register_checkout(
        reservation_id=payload.reservation_id,
        km=payload.km,
        photos=payload.photos,
        items=payload.items,
        notes=payload.notes,
        damage_fine=payload.damage_fine,
    )
    return {"id": checkout.id, "status": "completed"}

