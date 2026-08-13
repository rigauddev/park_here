# ParkHere QA Checklist

## Product Risks

- Double booking.
- Incorrect availability after cancellation, check-in, or checkout.
- Price mismatch between app estimate and backend charge.
- Reservation expiry not enforced.
- Add-on service not included in payment or operation queue.
- Check-in without confirmed reservation.
- Checkout without active session.

## Security And Privacy

- Tenant data leakage.
- JWT/MFA bypass.
- Hard-coded tenant or user IDs.
- Sensitive logs with OTP, token, phone, document, plate, or biometric data.
- Missing consent for future facial recognition.

## Backend Validation

- Unit tests for price calculation and state transitions.
- API tests for tenant isolation.
- Migration upgrade/downgrade check.
- Error responses for invalid state transitions.

## Flutter Validation

- `dart format`.
- `flutter analyze`.
- Widget/provider tests for reservation and checkout states.
- Manual test of the full happy path.
