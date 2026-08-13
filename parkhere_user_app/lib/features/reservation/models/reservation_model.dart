import '../../checkin_checkout/models/pre_checkin_model.dart';
import '../../parking_search/models/payment_plan_enum.dart';
import 'reservation_enum.dart';

class ReservationModel {
  final String id;
  final String parkingName;
  final PlanType plan;
  final ReservationStatus status;
  final DateTime checkinAt;
  final DateTime? checkoutAt;
  final double estimatedValue;
  final double? finalValue;
  final double firstHourPrice;
  final double additionalHourPrice;
  final DateTime checkinTime;
  final bool hasUnpaidServices;
  final double unpaidServicesValue;
  final DateTime validUntil;
  final PreCheckinModel preCheckin;
  final int? parkingRating;
  final int? appRating;
  final String? ratingComment;

  // Serviços adicionais
  final bool carWash;
  final bool tourGuide;
  final bool transport;

  ReservationModel({
    required this.id,
    required this.parkingName,
    required this.plan,
    required this.status,
    required this.checkinAt,
    this.checkoutAt,
    required this.estimatedValue,
    this.finalValue,
    required this.carWash,
    required this.tourGuide,
    required this.transport,
    required this.firstHourPrice,
    required this.additionalHourPrice,
    required this.checkinTime,
    required this.hasUnpaidServices,
    required this.unpaidServicesValue,
    required this.validUntil,
    required this.preCheckin,
    this.parkingRating,
    this.appRating,
    this.ratingComment,
  });

  ReservationModel copyWith({
    ReservationStatus? status,
    DateTime? checkoutAt,
    double? finalValue,
    bool? hasUnpaidServices,
    double? unpaidServicesValue,
    int? parkingRating,
    int? appRating,
    String? ratingComment,
  }) {
    return ReservationModel(
      id: id,
      parkingName: parkingName,
      plan: plan,
      status: status ?? this.status,
      checkinAt: checkinAt,
      checkoutAt: checkoutAt ?? this.checkoutAt,
      estimatedValue: estimatedValue,
      finalValue: finalValue ?? this.finalValue,
      carWash: carWash,
      tourGuide: tourGuide,
      transport: transport,
      firstHourPrice: firstHourPrice,
      additionalHourPrice: additionalHourPrice,
      checkinTime: checkinTime,
      hasUnpaidServices: hasUnpaidServices ?? this.hasUnpaidServices,
      unpaidServicesValue: unpaidServicesValue ?? this.unpaidServicesValue,
      validUntil: validUntil,
      preCheckin: preCheckin,
      parkingRating: parkingRating ?? this.parkingRating,
      appRating: appRating ?? this.appRating,
      ratingComment: ratingComment ?? this.ratingComment,
    );
  }
}
