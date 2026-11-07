"""Contract-level checks for the vehicle-rental module.

These tests intentionally avoid a database: they protect the API boundary and
the states that the mobile/web clients depend on while the integration suite
exercises the tenant and permission queries.
"""
import unittest
from datetime import datetime, timedelta, timezone

from pydantic import ValidationError

from app.modules.rentals.schemas.rental import (
    CheckinCreate,
    CheckoutCreate,
    ReservationCreate,
    VehicleCreate,
    VehicleOut,
)


class RentalModuleContractTests(unittest.TestCase):
    def test_vehicle_registration_accepts_legal_identifiers_and_media(self):
        vehicle = VehicleCreate(
            company_id="company-1",
            group_id="group-1",
            vehicle_type="car",
            brand="Fiat",
            model="Mobi",
            price_per_day=120,
            plate="ABC1D23",
            year=2025,
            manufacture_year=2025,
            crlv_code="CRLV-2025-001",
            renavam="12345678901",
            chassis="9BWZZZ377VT004251",
            photo_urls=["https://example.test/mobi.jpg"],
            specifications={"air_conditioning": True},
        )
        self.assertEqual(vehicle.renavam, "12345678901")
        self.assertEqual(vehicle.specifications["air_conditioning"], True)

    def test_nullable_legacy_vehicle_media_is_normalized_in_response(self):
        result = VehicleOut.model_validate({
            "id": "vehicle-1",
            "company_id": "company-1",
            "brand": "Fiat",
            "model": "Mobi",
            "price_per_day": 120,
            "photo_urls": None,
            "specifications": None,
            "status": "available",
            "is_active": True,
        })
        self.assertEqual(result.photo_urls, [])
        self.assertEqual(result.specifications, {})

    def test_reservation_requires_positive_period(self):
        start = datetime.now(timezone.utc)
        with self.assertRaises(ValidationError):
            ReservationCreate(
                company_id="company-1", vehicle_id="vehicle-1",
                start_date=start, end_date=start,
            )
        valid = ReservationCreate(
            company_id="company-1", vehicle_id="vehicle-1",
            start_date=start, end_date=start + timedelta(days=1),
        )
        self.assertGreater(valid.end_date, valid.start_date)

    def test_inspection_payload_limits_photo_count(self):
        with self.assertRaises(ValidationError):
            CheckinCreate(
                reservation_id="reservation-1",
                photos=["photo"] * 9,
            )
        checkout = CheckoutCreate(
            reservation_id="reservation-1", km=1000, damage_fine=75,
        )
        self.assertEqual(checkout.damage_fine, 75)


if __name__ == "__main__":
    unittest.main()
