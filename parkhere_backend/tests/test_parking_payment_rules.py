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
from app.modules.platform_fees.models import PlatformFee, PartnerPlatformFee, ParkingPlatformFee
from app.modules.platform_fees.service import PlatformFeeService
from app.modules.payments.service import _reservation_establishment_fee
from app.core.email_service import EmailService


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


class PlatformFeeOverrideTests(unittest.IsolatedAsyncioTestCase):
    async def test_partner_override_replaces_global_fee_only_for_that_tenant(self):
        global_fee = PlatformFee(
            service_type='parking', fee_mode='hybrid', fixed_amount=1,
            percentage=5, min_fee=0, max_fee=None, is_active=True,
        )
        override = PartnerPlatformFee(
            tenant_id='tenant1', service_type='parking', fee_mode='percentage',
            fixed_amount=0, percentage=12, min_fee=0, max_fee=None,
            is_active=True,
        )

        def scalar_result(rows):
            return SimpleNamespace(all=lambda: rows)

        db = AsyncMock()
        db.execute.return_value = SimpleNamespace(scalars=lambda: scalar_result([global_fee]))
        db.scalars.side_effect = [scalar_result([override]), scalar_result([])]

        partner_lines = await PlatformFeeService.calculate_lines(
            db, {'parking': 100}, tenant_id='tenant1'
        )
        other_lines = await PlatformFeeService.calculate_lines(
            db, {'parking': 100}, tenant_id='tenant2'
        )

        self.assertEqual(partner_lines[0].fee_amount, 12)
        self.assertEqual(other_lines[0].fee_amount, 6)

    async def test_unit_override_has_precedence_over_partner_and_global(self):
        global_fee = PlatformFee(
            service_type='parking', fee_mode='percentage', fixed_amount=0,
            percentage=5, min_fee=0, max_fee=None, is_active=True,
        )
        partner_fee = PartnerPlatformFee(
            tenant_id='tenant1', service_type='parking', fee_mode='percentage',
            fixed_amount=0, percentage=10, min_fee=0, max_fee=None,
            is_active=True,
        )
        unit_fee = ParkingPlatformFee(
            tenant_id='tenant1', parking_id='unit1', service_type='parking',
            fee_mode='percentage', fixed_amount=0, percentage=15,
            min_fee=0, max_fee=None, is_active=True,
        )

        def scalar_result(rows):
            return SimpleNamespace(all=lambda: rows)

        db = AsyncMock()
        db.execute.return_value = SimpleNamespace(scalars=lambda: scalar_result([global_fee]))
        db.scalars.side_effect = [scalar_result([partner_fee]), scalar_result([unit_fee])]
        lines = await PlatformFeeService.calculate_lines(
            db, {'parking': 100}, tenant_id='tenant1', parking_id='unit1'
        )
        self.assertEqual(lines[0].fee_amount, 15)

    async def test_payment_uses_reservation_rate_snapshot(self):
        reservation = SimpleNamespace(
            platform_fee_snapshot='[{"service_type":"parking","fee_amount":7.5}]',
            base_amount=100,
            selected_services_snapshot=None,
        )
        amount = await _reservation_establishment_fee(
            AsyncMock(), reservation, SimpleNamespace(tenant_id='tenant1', id='unit1')
        )
        self.assertEqual(amount, 7.5)


class EmailTemplateTests(unittest.IsolatedAsyncioTestCase):
    async def test_template_substitutions_are_escaped_and_use_inline_branding(self):
        template = SimpleNamespace(
            subject='Welcome {{name}}',
            header_html='<header>{{slogan}}</header>',
            body_html='<p>{{name}}: {{reason}}</p>',
            footer_html='<footer>{{company_footer}}</footer>',
        )
        db = AsyncMock()
        db.scalar.return_value = template
        with patch.object(EmailService, 'send_email', return_value=True) as send:
            sent = await EmailService.send_template(
                db, 'person@example.test', 'user_deactivation', 'en',
                {'name': '<script>bad</script>', 'reason': '<disabled>'},
            )
        self.assertTrue(sent)
        args = send.call_args.args
        self.assertEqual(args[0], 'person@example.test')
        self.assertIn('&lt;script&gt;bad&lt;/script&gt;', args[2])
        self.assertNotIn('<script>bad</script>', args[2])
        self.assertTrue(send.call_args.kwargs['inline_logo'])


if __name__ == '__main__':
    unittest.main()
