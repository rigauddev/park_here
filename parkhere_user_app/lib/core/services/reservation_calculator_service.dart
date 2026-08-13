import '../../features/parking_search/models/payment_plan_enum.dart';
import '../../features/reservation/models/reservation_model.dart';

double calculateFinalValue({
  required ReservationModel reservation,
  required double firstHourPrice,
  required double additionalHourPrice,
  required double dailyPrice,
}) {
  final now = DateTime.now();
  final duration = now.difference(reservation.checkinAt);
  final hours = duration.inHours == 0 ? 1 : duration.inHours;

  // 🔹 Plano por Hora
  if (reservation.plan == PlanType.hourly) {
    if (hours <= 1) return firstHourPrice;

    return firstHourPrice +
        ((hours - 1) * additionalHourPrice);
  }

  // 🔹 Plano Diária
  if (reservation.plan == PlanType.daily) {
    if (hours <= 24) return dailyPrice;

    final extraHours = hours - 24;

    return dailyPrice + (extraHours * additionalHourPrice);
  }

  // 🔹 Mensal
  return reservation.estimatedValue;
}
