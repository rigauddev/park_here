import io
import unittest
from datetime import datetime, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch
from urllib.error import HTTPError

from fastapi import HTTPException
from pydantic import ValidationError

from app.modules.parkings.schemas import ParkingAreaPricing, ParkingManagementRequest, ParkingServiceInput
from app.modules.payments.mercado_pago import MercadoPagoClient, MercadoPagoError
from app.modules.payments.schemas import CreatePaymentIntentRequest
from app.modules.payments.service import PaymentService, _ensure_payable_reservation, settings
from app.modules.users.models.user_model_role_enum import UserRoleEnum
from app.modules.reservations.service import _selected_services


class ParkingRulesTests(unittest.TestCase):
    def test_prices_reject_negative_and_non_finite(self):
        for price in (-1, float('nan'), float('inf')):
            with self.subTest(price=price):
                with self.assertRaises(ValidationError):
                    ParkingAreaPricing(first_hour_price=price)
                with self.assertRaises(ValidationError):
                    ParkingServiceInput(code='wash', name='Lavagem', price=price)

    def test_duplicate_catalog_code_rejected(self):
        service = dict(code='wash', name='Lavagem', price=20)
        with self.assertRaises(ValidationError):
            ParkingManagementRequest(
                name='Centro', address='Valenca', lat=-13.37, lng=-39.07,
                total_spots=10, uncovered_spots=10, uncovered_pricing={},
                services=[service, service],
            )

    def test_repeated_selection_charged_once(self):
        service = SimpleNamespace(code='wash', price=20, is_active=True)
        self.assertEqual(_selected_services([service], ['wash', 'wash']), [service])

    def test_inactive_service_rejected(self):
        with self.assertRaises(HTTPException):
            _selected_services([SimpleNamespace(code='wash', is_active=False)], ['wash'])

    def test_terminal_and_expired_reservations_cannot_be_paid(self):
        for status in ('cancelled', 'expired', 'completed', 'pre_reserved'):
            with self.subTest(status=status), self.assertRaises(HTTPException):
                _ensure_payable_reservation(SimpleNamespace(
                    status=status, hold_expires_at=datetime.utcnow() - timedelta(minutes=1),
                ))

    def test_unknown_payment_method_rejected(self):
        with self.assertRaises(ValidationError):
            CreatePaymentIntentRequest(method='arbitrary')


class MercadoPagoClientTests(unittest.IsolatedAsyncioTestCase):
    async def test_pix_sends_stable_idempotency_key_and_backend_amount(self):
        with patch('app.modules.payments.mercado_pago.urlopen', return_value=io.BytesIO(b'{"id":123}')) as transport:
            result = await MercadoPagoClient('test-token').create_pix(
                amount=12.50, payer_email='test@example.com',
                external_reference='reservation:123', idempotency_key='persisted-key',
            )
        self.assertEqual(result['id'], 123)
        request = transport.call_args.args[0]
        self.assertEqual(request.get_header('X-idempotency-key'), 'persisted-key')
        self.assertEqual(request.full_url, 'https://api.mercadopago.com/v1/payments')
        self.assertIn(b'12.5', request.data)

    async def test_provider_error_does_not_expose_body_or_token(self):
        error = HTTPError('https://api.mercadopago.com', 401, 'secret', {}, None)
        with patch('app.modules.payments.mercado_pago.urlopen', side_effect=error):
            with self.assertRaisesRegex(MercadoPagoError, '^Mercado Pago returned HTTP 401$'):
                await MercadoPagoClient('secret').get_payment('123')

    async def test_payment_id_cannot_change_request_path(self):
        with self.assertRaises(ValueError):
            await MercadoPagoClient('test').get_payment('../users')


class PaymentConfirmationTests(unittest.IsolatedAsyncioTestCase):
    async def assert_confirmation_rejected(self, *, provider='mock', status='cancelled', owner='customer', expected=409):
        transaction = SimpleNamespace(reservation_id='r1', provider=provider, status='pending', method='pix')
        db = AsyncMock()
        db.execute.return_value = Mock(scalar_one_or_none=Mock(return_value=transaction))
        reservation = SimpleNamespace(user_id=owner, parking_id='p1', status=status)
        parking = SimpleNamespace(tenant_id='tenant1')
        user = SimpleNamespace(id='customer', role=UserRoleEnum.CUSTOMER)
        with patch.object(settings, 'PAYMENT_PROVIDER', 'mock'), patch(
            'app.modules.payments.service._get_reservation', AsyncMock(return_value=reservation)
        ), patch('app.modules.payments.service._get_parking', AsyncMock(return_value=parking)):
            with self.assertRaises(HTTPException) as caught:
                await PaymentService.confirm_payment(db, 'payment1', user)
        self.assertEqual(caught.exception.status_code, expected)
        self.assertEqual(transaction.status, 'pending')
        db.commit.assert_not_called()

    async def test_real_provider_cannot_be_manually_confirmed(self):
        await self.assert_confirmation_rejected(provider='mercado_pago', status='confirmed', expected=403)

    async def test_cancelled_reservation_is_not_reopened(self):
        await self.assert_confirmation_rejected()

    async def test_other_customer_payment_is_forbidden(self):
        await self.assert_confirmation_rejected(owner='other-customer', expected=403)


if __name__ == '__main__':
    unittest.main()
