from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, date

from .models.rental_company import RentalCompany
from .models.vehicle import Vehicle
from .models.rental_reservation import RentalReservation
from .models.rental_checkin import RentalCheckin
from .models.rental_checkout import RentalCheckout

class RentalService:
    """Business logic for the rental module.
    This class orchestrates CRUD operations using the SQLAlchemy session.
    More advanced rules (pricing, PDF generation, fine association) can be
    added later.
    """

    def __init__(self, db: Session):
        self.db = db

    # ---------- Companies -------------------------------------------------
    def list_companies(self) -> List[RentalCompany]:
        return self.db.query(RentalCompany).filter(RentalCompany.is_active == True).all()

    def get_company(self, company_id: str) -> Optional[RentalCompany]:
        return self.db.query(RentalCompany).filter(RentalCompany.id == company_id).first()

    # ---------- Vehicles --------------------------------------------------
    def list_vehicles(self, company_id: str) -> List[Vehicle]:
        return (
            self.db.query(Vehicle)
            .filter(Vehicle.company_id == company_id, Vehicle.status == "available")
            .all()
        )

    def get_vehicle(self, vehicle_id: str) -> Optional[Vehicle]:
        return self.db.query(Vehicle).filter(Vehicle.id == vehicle_id).first()

    # ---------- Reservations ---------------------------------------------
    def create_reservation(
        self,
        partner_id: str,
        company_id: str,
        vehicle_id: str,
        start_date: datetime,
        end_date: datetime,
        extras: Optional[dict] = None,
        km_start: Optional[int] = None,
    ) -> RentalReservation:
        vehicle = self.get_vehicle(vehicle_id)
        days = (end_date - start_date).days or 1
        total = vehicle.price_per_day * days
        reservation = RentalReservation(
            partner_id=partner_id,
            company_id=company_id,
            vehicle_id=vehicle_id,
            start_date=start_date,
            end_date=end_date,
            total_price=total,
            status="pending",
            extras=extras,
            km_start=km_start,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
        )
        self.db.add(reservation)
        vehicle.status = "reserved"
        self.db.commit()
        self.db.refresh(reservation)
        return reservation

    def get_reservation(self, reservation_id: str) -> Optional[RentalReservation]:
        return (
            self.db.query(RentalReservation)
            .filter(RentalReservation.id == reservation_id)
            .first()
        )

    # ---------- Check‑in -------------------------------------------------
    def register_checkin(
        self,
        reservation_id: str,
        km: Optional[int] = None,
        photos: Optional[list] = None,
        items: Optional[dict] = None,
        notes: Optional[str] = None,
    ) -> RentalCheckin:
        checkin = RentalCheckin(
            reservation_id=reservation_id,
            timestamp=datetime.utcnow(),
            km=km,
            photos=photos,
            items=items,
            notes=notes,
        )
        self.db.add(checkin)
        reservation = self.get_reservation(reservation_id)
        reservation.status = "checked_in"
        reservation.updated_at = datetime.utcnow()
        self.db.commit()
        self.db.refresh(checkin)
        return checkin

    # ---------- Checkout -------------------------------------------------
    def register_checkout(
        self,
        reservation_id: str,
        km: Optional[int] = None,
        photos: Optional[list] = None,
        items: Optional[dict] = None,
        notes: Optional[str] = None,
        damage_fine: Optional[float] = 0.0,
    ) -> RentalCheckout:
        checkout = RentalCheckout(
            reservation_id=reservation_id,
            timestamp=datetime.utcnow(),
            km=km,
            photos=photos,
            items=items,
            notes=notes,
            damage_fine=damage_fine,
        )
        self.db.add(checkout)
        reservation = self.get_reservation(reservation_id)
        reservation.status = "completed"
        reservation.km_end = km
        reservation.updated_at = datetime.utcnow()
        vehicle = self.get_vehicle(reservation.vehicle_id)
        vehicle.status = "available"
        self.db.commit()
        self.db.refresh(checkout)
        return checkout

    # ---------- Fines (cron) --------------------------------------------
    def associate_fines(self, day: date) -> int:
        """Placeholder implementation – in a real system this would call an
        external traffic‑incident service, match fines to reservations and create
        charge records. Returns the number of processed fines.
        """
        return 0

