import '../../parking_search/models/payment_plan_enum.dart';
import '../../reservation/models/reservation_model.dart';
import '../providers/checkout_strategy.dart';

class CheckoutService {

  static double calculate(ReservationModel reservation) {

    late CheckoutStrategy strategy;

    switch (reservation.plan) {

      case PlanType.hourly:
        strategy = HourlyCheckoutStrategy();
        break;

      case PlanType.daily:
        strategy = DailyCheckoutStrategy();
        break;

      case PlanType.monthly:
        strategy = MonthlyCheckoutStrategy();
        break;
    }

    return strategy.calculate(reservation);
  }
}