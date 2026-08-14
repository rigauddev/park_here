import '../../parking_search/models/payment_plan_enum.dart';
import '../../parking_search/models/parking_model.dart';

class PreCheckinModel {
  final ParkingModel parking;
  final PlanType plan;

  // Serviços escolhidos
  final bool carWash;
  final bool tourGuide;
  final bool transport;

  // Localização do usuário no momento do check-in
  final double userLocationLat;
  final double userLocationLng;

  final double total;
  final String? reservationId;
  final double platformFeeAmount;

  const PreCheckinModel({
    required this.parking,
    required this.plan,
    required this.carWash,
    required this.tourGuide,
    required this.transport,
    required this.total,
    this.reservationId,
    this.platformFeeAmount = 0,
    required this.userLocationLat,
    required this.userLocationLng,
  });
}

class CheckinCheckoutError extends Error {
  final String message;
  CheckinCheckoutError(this.message);
}
