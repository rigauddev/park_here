import 'package:flutter_test/flutter_test.dart';
import 'package:parkhere_user_app/features/reservation/models/reservation_enum.dart';
import 'package:parkhere_user_app/features/reservation/services/reservation_cancellation_rules.dart';

void main() {
  final now = DateTime(2026, 9, 14, 12);

  test('allows cancelling an unpaid, unexpired pre-reservation', () {
    expect(
      ReservationCancellationRules.canCustomerCancel(
        apiStatus: 'pre_reserved',
        paymentStatus: 'pending_checkin',
        status: ReservationStatus.open,
        holdExpiresAt: now.add(const Duration(minutes: 5)),
        now: now,
      ),
      isTrue,
    );
  });

  test('hides cancellation after hold expiry', () {
    expect(
      ReservationCancellationRules.canCustomerCancel(
        apiStatus: 'pre_reserved',
        paymentStatus: 'expired',
        status: ReservationStatus.expired,
        holdExpiresAt: now,
        now: now,
      ),
      isFalse,
    );
  });

  test('does not offer direct cancellation after payment', () {
    expect(
      ReservationCancellationRules.canCustomerCancel(
        apiStatus: 'confirmed',
        paymentStatus: 'paid',
        status: ReservationStatus.open,
        holdExpiresAt: now.add(const Duration(hours: 1)),
        now: now,
      ),
      isFalse,
    );
  });

  test('does not offer customer cancellation after check-in', () {
    expect(
      ReservationCancellationRules.canCustomerCancel(
        apiStatus: 'checked_in',
        paymentStatus: 'paid',
        status: ReservationStatus.open,
        holdExpiresAt: now.add(const Duration(hours: 1)),
        now: now,
      ),
      isFalse,
    );
  });
}
