import '../models/reservation_enum.dart';

class ReservationCancellationRules {
  const ReservationCancellationRules._();

  static bool canCustomerCancel({
    required String apiStatus,
    required String paymentStatus,
    required ReservationStatus status,
    bool checkedIn = false,
    required DateTime holdExpiresAt,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    return (apiStatus == 'pre_reserved' ||
            apiStatus == 'pending_operator_approval') &&
        paymentStatus != 'paid' &&
        paymentStatus != 'expired' &&
        status == ReservationStatus.open &&
        // The API status is authoritative. A failed geolocation check must
        // never hide cancellation because a local screen briefly opened the
        // check-in flow.
        (apiStatus == 'pre_reserved' ||
            apiStatus == 'pending_operator_approval' ||
            !checkedIn) &&
        holdExpiresAt.isAfter(currentTime);
  }
}
