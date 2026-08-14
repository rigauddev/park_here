import '../../reservation/models/reservation_model.dart';

abstract class CheckoutStrategy {
  double calculate(ReservationModel reservation);
}

class HourlyCheckoutStrategy implements CheckoutStrategy {
  @override
  double calculate(ReservationModel reservation) {
    final now = DateTime.now();
    final duration = now.difference(reservation.checkinTime);

    int hours = duration.inHours;

    if (hours <= 1) {
      hours = 1;
    }

    double total = reservation.firstHourPrice;

    if (hours > 1) {
      total += (hours - 1) * reservation.additionalHourPrice;
    }

    if (reservation.hasUnpaidServices) {
      total += reservation.unpaidServicesValue;
    }

    return total;
  }
}

class DailyCheckoutStrategy implements CheckoutStrategy {
  @override
  double calculate(ReservationModel reservation) {
    double total = 0;

    final now = DateTime.now();

    if (now.isAfter(reservation.validUntil)) {
      total += reservation.additionalHourPrice;
    }

    if (reservation.hasUnpaidServices) {
      total += reservation.unpaidServicesValue;
    }

    return total;
  }
}

class MonthlyCheckoutStrategy implements CheckoutStrategy {
  @override
  double calculate(ReservationModel reservation) {
    final now = DateTime.now();

    if (now.isAfter(reservation.validUntil)) {
      throw Exception("Plano mensal vencido");
    }

    double total = 0;

    if (reservation.hasUnpaidServices) {
      total += reservation.unpaidServicesValue;
    }

    return total;
  }
}
