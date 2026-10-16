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
        // Após o check-in a reserva não pode ser cancelada diretamente.
        // O cliente deverá seguir o fluxo de checkout/reembolso.
        !checkedIn &&
        holdExpiresAt.isAfter(currentTime);
  }
}
