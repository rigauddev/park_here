import '../../parking_search/models/payment_plan_enum.dart';
import 'reservation_enum.dart';

class ReservationFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final ReservationStatus? status;
  final PlanType? plan;
  final String? parkingName;

  ReservationFilter({
    this.startDate,
    this.endDate,
    this.status,
    this.plan,
    this.parkingName,
  });
}
