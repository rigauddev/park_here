import '../../parking_search/models/payment_plan_enum.dart';

class ParkingSessionModel {
  final String sessionId;
  final String parkingId;

  final PlanType plan;

  final DateTime checkInTime;
  final DateTime? checkOutTime;

  final double estimatedTotal;
  final double? finalTotal;

  const ParkingSessionModel({
    required this.sessionId,
    required this.parkingId,
    required this.plan,
    required this.checkInTime,
    this.checkOutTime,
    required this.estimatedTotal,
    this.finalTotal,
  });

  ParkingSessionModel copyWith({
    DateTime? checkOutTime,
    double? finalTotal,
  }) {
    return ParkingSessionModel(
      sessionId: sessionId,
      parkingId: parkingId,
      plan: plan,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      estimatedTotal: estimatedTotal,
      finalTotal: finalTotal ?? this.finalTotal,
    );
  }
}

