import '../models/reservation_enum.dart';

class ReservationCancellationRules {
  const ReservationCancellationRules._();

  static bool canCustomerCancel({
    required String apiStatus,
    required String paymentStatus,
    required ReservationStatus status,
    required DateTime holdExpiresAt,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    return apiStatus == 'pre_reserved' &&
        paymentStatus != 'paid' &&
        paymentStatus != 'expired' &&
        status == ReservationStatus.open &&
        holdExpiresAt.isAfter(currentTime);
  }
}
