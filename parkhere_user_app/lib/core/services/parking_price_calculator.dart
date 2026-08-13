import '../../features/parking_search/models/payment_plan_enum.dart';
import '../../features/parking_search/models/parking_model.dart';

class ParkingPriceCalculator {
  /// ===============================
  /// ✅ Calcula valor final baseado no plano e tempo real
  /// ===============================
  static double calculateTotal({
    required ParkingModel parking,
    required PlanType plan,
    required DateTime checkInTime,
    required DateTime checkOutTime,
  }) {
    switch (plan) {
      case PlanType.hourly:
        return _calculateHourly(parking, checkInTime, checkOutTime);

      case PlanType.daily:
        return parking.pricing.dailyPrice;

      case PlanType.monthly:
        return parking.pricing.monthlyPrice;
    }
  }

  /// ===============================
  /// ✅ Plano por hora (primeira hora + adicionais)
  /// ===============================
  static double _calculateHourly(
    ParkingModel parking,
    DateTime checkIn,
    DateTime checkOut,
  ) {
    // Tempo total em minutos
    final minutes = checkOut.difference(checkIn).inMinutes;

    if (minutes <= 0) return 0;

    // Converter para horas arredondando para cima
    final totalHours = (minutes / 60).ceil();

    // Primeira hora sempre cobrada
    if (totalHours == 1) {
      return parking.pricing.firstHourPrice;
    }

    // Horas adicionais
    final additionalHours = totalHours - 1;

    return parking.pricing.firstHourPrice +
        (additionalHours * parking.pricing.additionalHourPrice);
  }
}
