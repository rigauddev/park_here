import '../models/filter_model.dart';
import '../models/reservation_model.dart';

List<ReservationModel> applyFilters(
  List<ReservationModel> list,
  ReservationFilter filter,
) {
  return list.where((r) {

    if (filter.status != null && r.status != filter.status) {
      return false;
    }

    if (filter.plan != null && r.plan != filter.plan) {
      return false;
    }

    if (filter.parkingName != null &&
        !r.parkingName
            .toLowerCase()
            .contains(filter.parkingName!.toLowerCase())) {
      return false;
    }

    if (filter.startDate != null &&
        r.checkinAt.isBefore(filter.startDate!)) {
      return false;
    }

    if (filter.endDate != null &&
        r.checkinAt.isAfter(filter.endDate!)) {
      return false;
    }

    return true;
  }).toList();
}
