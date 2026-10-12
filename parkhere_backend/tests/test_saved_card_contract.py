import unittest
from datetime import datetime, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

from pydantic import ValidationError

from app.modules.customer_assets.router import SavedCardRequest
from app.modules.reservations.service import expire_parking_reservations


class SavedCardContractTests(unittest.TestCase):
    def test_accepts_only_masked_card_display_metadata(self):
        card = SavedCardRequest(
            method_type="credit_card",
            brand="Visa",
            cardholder_name="Cliente Teste",
            last_four="4242",
            expiration_month=12,
            expiration_year=2030,
            is_default=True,
        )
        self.assertEqual(card.last_four, "4242")

    def test_rejects_full_pan_and_cvv_fields(self):
        with self.assertRaises(ValidationError):
            SavedCardRequest(
                method_type="credit_card",
                brand="Visa",
                cardholder_name="Cliente Teste",
                last_four="4242",
                expiration_month=12,
                expiration_year=2030,
                card_number="4111111111111111",
                cvv="123",
            )

    def test_rejects_pix_as_customer_saved_card(self):
        with self.assertRaises(ValidationError):
            SavedCardRequest(
                method_type="pix",
                brand="Pix",
                cardholder_name="Cliente Teste",
                last_four="4242",
                expiration_month=12,
                expiration_year=2030,
            )


class ReservationExpiryTests(unittest.IsolatedAsyncioTestCase):
    async def test_expiry_cancels_hold_and_releases_the_spot(self):
        reservation = SimpleNamespace(
            status="pre_reserved",
            payment_status="pending_checkin",
            hold_expires_at=datetime.utcnow() - timedelta(minutes=1),
            cancelled_at=None,
            cancellation_reason=None,
        )
        result = Mock()
        result.all.return_value = [reservation]
        db = SimpleNamespace(
            scalars=AsyncMock(return_value=result),
            flush=AsyncMock(),
        )
        parking = SimpleNamespace(id="parking-test", total_spots=10, available_spots=4)

        await expire_parking_reservations(db, parking)

        self.assertEqual(reservation.status, "cancelled")
        self.assertEqual(reservation.payment_status, "expired")
        self.assertIsNotNone(reservation.cancelled_at)
        self.assertIn("expirada", reservation.cancellation_reason)
        self.assertEqual(parking.available_spots, 5)
        db.flush.assert_awaited_once()
