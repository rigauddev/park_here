"""Opt-in HTTP/MySQL tests. Fixtures use unique tenants and are removed afterwards.

RUN_PILOT_HTTP=1 python -m unittest tests.test_pilot_http -v
Requires API on localhost:8000, current migrations and PAYMENT_PROVIDER=mock.
"""
import asyncio
import json
import os
import unittest
import uuid
from datetime import datetime, timedelta
from urllib.request import Request, urlopen
from urllib.error import HTTPError

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from sqlalchemy.pool import NullPool
from app.core.config import settings
from app.core.security import create_access_token
from app.modules.tenants.models.tenant_models import Tenant, TenantStatusEnum
from app.modules.users.models.user_model import User
from app.modules.users.models.user_model_role_enum import UserRoleEnum
from app.modules.partners.models import PartnerProfile
from app.modules.parkings.models import Parking, ParkingService
from app.modules.reservations.models import Reservation
from app.modules.payments.models import PaymentTransaction, PartnerFeeDebt, PartnerFeeSettlement
from app.modules.customer_assets.models import Vehicle


@unittest.skipUnless(os.getenv('RUN_PILOT_HTTP') == '1', 'Opt-in real HTTP/MySQL test')
class PilotHTTPTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.engine = create_async_engine(settings.DATABASE_URL, poolclass=NullPool)
        self.session = async_sessionmaker(self.engine, expire_on_commit=False)
        self.tenants, self.users, self.parkings = [], [], []
        async with self.session() as db:
            for index in range(2):
                uid = uuid.uuid4().hex
                tenant = Tenant(name='Pilot test Valenca', cnpj=uid[:18], email=f'{uid}@test.invalid', status=TenantStatusEnum.ACTIVE)
                db.add(tenant)
                await db.flush()
                user = User(tenant_id=tenant.id, name='Pilot manager', firt_name='Pilot', email=f'm{uid}@test.invalid', password_hash='not-a-login', role=UserRoleEnum.PARTNER_MANAGER)
                db.add(user)
                db.add(PartnerProfile(tenant_id=tenant.id, service_type='parking', company_name='Pilot', cnpj=uid[:18], registration_status='test', responsible_name='Pilot', approval_status='approved'))
                parking = Parking(tenant_id=tenant.id, name=f'Pilot {uid}', address='Valenca BA', city='Valenca', lat=-13.37, lng=-39.07, total_spots=10, available_spots=10, uncovered_spots=10,
                    first_hour_price=7, uncovered_first_hour_price=7, additional_hour_price=2, uncovered_additional_hour_price=2, daily_price=7, uncovered_daily_price=7)
                db.add(parking)
                await db.flush()
                db.add(ParkingService(parking_id=parking.id, code='car_wash', name='Lavagem', price=5))
                self.tenants.append(tenant.id)
                self.users.append(user)
                self.parkings.append(parking.id)
            customer = User(name='Pilot customer', firt_name='Pilot', email=f'c{uuid.uuid4().hex}@test.invalid', password_hash='not-a-login', role=UserRoleEnum.CUSTOMER)
            db.add(customer)
            await db.flush()
            vehicle = Vehicle(user_id=customer.id, nickname='Carro', plate='ABC1D23', brand='Fiat', model='Uno', color='Prata', vehicle_document='test', ownership_type='owner', is_active=True)
            db.add(vehicle)
            operator = User(tenant_id=self.tenants[0], name='Pilot operator', firt_name='Pilot', email=f'o{uuid.uuid4().hex}@test.invalid', password_hash='not-a-login', role=UserRoleEnum.OPERATOR)
            db.add(operator)
            await db.commit()
            self.customer, self.vehicle, self.operator = customer, vehicle, operator

    def token(self, user):
        return create_access_token({'sub': user.email, 'tenant_id': user.tenant_id, 'role': user.role.value})

    async def request(self, path, data=None, user=None, expected=200):
        user = user or self.users[0]
        def send():
            req = Request('http://127.0.0.1:8000' + path,
                data=json.dumps(data).encode() if data is not None else None,
                headers={'Authorization': 'Bearer ' + self.token(user), 'Content-Type': 'application/json'})
            try:
                with urlopen(req, timeout=15) as r:
                    return r.status, json.load(r)
            except HTTPError as e:
                return e.code, json.load(e)
        status, body = await asyncio.to_thread(send)
        if expected is not None:
            self.assertEqual(status, expected, body)
        return body if expected is not None else (status, body)

    async def reserve(self, code='V001', user=None, **kwargs):
        return await self.request('/reservations/pre-checkin', dict(
            parking_id=self.parkings[0], spot_code=code, spot_type='uncovered',
            route_minutes=1, arrival_now=True, is_manual_arrival=True,
            walk_in_plate='ABC-1234', walk_in_phone='(75) 99999-0000', **kwargs), user=user)

    async def pay(self, reservation, method='pix'):
        intent = await self.request(f'/payments/reservations/{reservation["id"]}/intent',
            {'method': method, 'cash_received': 100 if method == 'cash' else None})
        return await self.request(f'/payments/{intent["id"]}/confirm', {})

    async def test_customer_city_services_payment_checkin_checkout(self):
        parkings = await self.request('/parkings?city=Valenca', user=self.customer)
        self.assertIn(self.parkings[0], [p['id'] for p in parkings])
        reservation = await self.request('/reservations/pre-checkin', {
            'parking_id': self.parkings[0], 'vehicle_id': self.vehicle.id,
            'route_minutes': 10, 'spot_type': 'uncovered', 'service_codes': ['car_wash', 'car_wash']}, user=self.customer)
        self.assertEqual(reservation['services_amount'], 5)
        self.assertEqual(reservation['spot_code'], 'V001')
        intent = await self.request(f'/payments/reservations/{reservation["id"]}/intent', {'method': 'pix'}, user=self.customer)
        self.assertEqual(intent['gross_amount'], reservation['final_total'])
        await self.request(f'/payments/{intent["id"]}/confirm', {}, user=self.customer)
        await self.request(f'/reservations/{reservation["id"]}/checkin', {})
        result = await self.request(f'/reservations/{reservation["id"]}/checkout', {})
        self.assertEqual(result['status'], 'completed')
        layout = await self.request('/partners/parking-map')
        self.assertEqual(layout['parkings'][0]['available_spots'], 10)

    async def test_walkin_pix_arrival_is_now_and_tenant_isolation(self):
        start = datetime.utcnow()
        r = await self.reserve()
        arrival = datetime.fromisoformat(r['arrival_estimate_at'].replace('Z', '+00:00')).replace(tzinfo=None)
        self.assertLess(abs((arrival - start).total_seconds()), 10)
        self.assertEqual(r['walk_in_plate'], 'ABC1234')
        await self.request(f'/payments/reservations/{r["id"]}/intent', {'method': 'pix'}, user=self.users[1], expected=403)
        await self.pay(r)
        other = await self.request('/partners/reservations', user=self.users[1])
        self.assertNotIn(r['id'], [x['id'] for x in other])

    async def test_same_spot_concurrency_and_cancellation(self):
        payload = dict(parking_id=self.parkings[0], spot_code='V001', spot_type='uncovered', route_minutes=1, arrival_now=True, walk_in_plate='ABC1234', walk_in_phone='75999990000')
        responses = await asyncio.gather(*[self.request('/reservations/pre-checkin', payload, expected=None) for _ in range(2)])
        self.assertEqual(sorted(s for s, _ in responses), [200, 409])
        r = next(body for status, body in responses if status == 200)
        cancelled = await self.request(f'/reservations/{r["id"]}/cancel', {})
        self.assertEqual(cancelled['cancellation_fee_amount'], 0)
        self.assertEqual(cancelled['cancellation_credit_amount'], 0)
        await self.request(f'/payments/reservations/{r["id"]}/intent', {'method': 'pix'}, expected=409)
        await self.reserve()

    async def test_cash_debt_partial_and_repeated_confirmation(self):
        r = await self.reserve()
        # Precisely reproduce the requested 10 = 7 partner + 3 platform example.
        async with self.session() as db:
            row = await db.get(Reservation, r['id'])
            row.base_amount, row.final_total, row.estimated_total, row.platform_fee_amount = 7, 10, 10, 3
            await db.commit()
        paid = await self.pay(r, 'cash')
        await self.request(f'/payments/{paid["id"]}/confirm', {})
        statement = await self.request('/partners/fee-statement')
        self.assertEqual(statement['pending_total'], 3)
        self.assertEqual(len(statement['debts']), 1)
        online = await self.reserve('V002')
        async with self.session() as db:
            row = await db.get(Reservation, online['id'])
            row.final_total, row.estimated_total, row.platform_fee_amount = 3, 3, 1
            await db.commit()
        payment = await self.pay(online)
        self.assertEqual(payment['partner_amount'], 0)
        self.assertEqual(payment['withheld_fee_amount'], 2)
        await self.request(f'/payments/{payment["id"]}/confirm', {})
        statement = await self.request('/partners/fee-statement')
        self.assertEqual(statement['pending_total'], 1)
        self.assertEqual(len(statement['settlements']), 1)
        other = await self.request('/partners/fee-statement', user=self.users[1])
        self.assertEqual(other['pending_total'], 0)
        await self.request('/partners/fee-statement', user=self.operator, expected=403)
        next_payment = await self.pay(await self.reserve('V003'))
        self.assertEqual(next_payment['withheld_fee_amount'], 1)
        self.assertEqual((await self.request('/partners/fee-statement'))['pending_total'], 0)

    async def test_operator_cannot_cancel_after_checkin(self):
        r = await self.reserve(user=self.operator)
        await self.request(f'/reservations/{r["id"]}/checkin', {}, user=self.operator)
        await self.request(f'/reservations/{r["id"]}/cancel', {}, user=self.operator, expected=403)
        await self.request(f'/reservations/{r["id"]}/cancel', {})

    async def asyncTearDown(self):
        async with self.session() as db:
            debt_ids = select(PartnerFeeDebt.id).where(PartnerFeeDebt.tenant_id.in_(self.tenants))
            await db.execute(delete(PartnerFeeSettlement).where(PartnerFeeSettlement.debt_id.in_(debt_ids)))
            for model in [PartnerFeeDebt, PaymentTransaction]:
                await db.execute(delete(model).where(model.tenant_id.in_(self.tenants)))
            await db.execute(delete(Reservation).where(Reservation.parking_id.in_(self.parkings)))
            await db.execute(delete(ParkingService).where(ParkingService.parking_id.in_(self.parkings)))
            await db.execute(delete(Parking).where(Parking.id.in_(self.parkings)))
            await db.execute(delete(Vehicle).where(Vehicle.user_id == self.customer.id))
            await db.execute(delete(User).where(User.id.in_([u.id for u in self.users] + [self.customer.id, self.operator.id])))
            await db.execute(delete(PartnerProfile).where(PartnerProfile.tenant_id.in_(self.tenants)))
            await db.execute(delete(Tenant).where(Tenant.id.in_(self.tenants)))
            await db.commit()
        await self.engine.dispose()
