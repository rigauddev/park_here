import '../../checkin_checkout/models/pre_checkin_model.dart';
import '../../parking_search/models/payment_plan_enum.dart';
import '../../parking_search/models/parking_model.dart';
import '../../parking_search/models/parking_pricing.dart';
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
  final bool checkedIn;

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
    this.checkedIn = false,
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
      checkedIn: checkedIn,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'parkingName': parkingName,
    'plan': plan.name,
    'status': status.name,
    'checkinAt': checkinAt.toIso8601String(),
    'checkoutAt': checkoutAt?.toIso8601String(),
    'estimatedValue': estimatedValue,
    'finalValue': finalValue,
    'firstHourPrice': firstHourPrice,
    'additionalHourPrice': additionalHourPrice,
    'checkinTime': checkinTime.toIso8601String(),
    'hasUnpaidServices': hasUnpaidServices,
    'unpaidServicesValue': unpaidServicesValue,
    'validUntil': validUntil.toIso8601String(),
    'carWash': carWash,
    'tourGuide': tourGuide,
    'transport': transport,
    'checkedIn': checkedIn,
    'parking': {
      'id': preCheckin.parking.id,
      'name': preCheckin.parking.name,
      'city': preCheckin.parking.city,
      'lat': preCheckin.parking.lat,
      'lng': preCheckin.parking.lng,
      'rating': preCheckin.parking.rating,
      'availableSpots': preCheckin.parking.availableSpots,
      'coveredSpots': preCheckin.parking.coveredSpots,
      'uncoveredSpots': preCheckin.parking.uncoveredSpots,
      'vipSpots': preCheckin.parking.vipSpots,
      'largeSpots': preCheckin.parking.largeSpots,
      'busSpots': preCheckin.parking.busSpots,
      'pickupSpots': preCheckin.parking.pickupSpots,
      'motoHomeSpots': preCheckin.parking.motoHomeSpots,
      'hasCoveredArea': preCheckin.parking.hasCoveredArea,
      'hasVipSpots': preCheckin.parking.hasVipSpots,
      'hasCarWash': preCheckin.parking.hasCarWash,
      'hasTourGuide': preCheckin.parking.hasTourGuide,
      'hasTransportService': preCheckin.parking.hasTransportService,
      'carWashPrice': preCheckin.parking.carWashPrice,
      'tourGuidePrice': preCheckin.parking.tourGuidePrice,
      'transportPrice': preCheckin.parking.transportPrice,
      'pricing': {
        'firstHourPrice': preCheckin.parking.pricing.firstHourPrice,
        'additionalHourPrice': preCheckin.parking.pricing.additionalHourPrice,
        'dailyPrice': preCheckin.parking.pricing.dailyPrice,
        'monthlyPrice': preCheckin.parking.pricing.monthlyPrice,
        'weeklyPrice': preCheckin.parking.pricing.weeklyPrice,
        'coveredDailyPrice': preCheckin.parking.pricing.coveredDailyPrice,
        'uncoveredDailyPrice': preCheckin.parking.pricing.uncoveredDailyPrice,
        'coveredFirstHourPrice':
            preCheckin.parking.pricing.coveredFirstHourPrice,
        'uncoveredFirstHourPrice':
            preCheckin.parking.pricing.uncoveredFirstHourPrice,
      },
    },
    'userLocationLat': preCheckin.userLocationLat,
    'userLocationLng': preCheckin.userLocationLng,
    'platformFeeAmount': preCheckin.platformFeeAmount,
  };

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    final parking = ParkingModel.fromJson(
      json['parking'] as Map<String, dynamic>,
    );
    final planName = json['plan'] as String? ?? PlanType.hourly.name;
    final statusName = json['status'] as String? ?? ReservationStatus.open.name;
    return ReservationModel(
      id: json['id'] as String,
      parkingName: json['parkingName'] as String? ?? parking.name,
      plan: PlanType.values.firstWhere(
        (value) => value.name == planName,
        orElse: () => PlanType.hourly,
      ),
      status: ReservationStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => ReservationStatus.open,
      ),
      checkinAt: DateTime.parse(json['checkinAt'] as String),
      checkoutAt: (json['checkoutAt'] as String?) == null
          ? null
          : DateTime.parse(json['checkoutAt'] as String),
      estimatedValue: (json['estimatedValue'] as num?)?.toDouble() ?? 0,
      finalValue: (json['finalValue'] as num?)?.toDouble(),
      carWash: json['carWash'] as bool? ?? false,
      tourGuide: json['tourGuide'] as bool? ?? false,
      transport: json['transport'] as bool? ?? false,
      checkedIn: json['checkedIn'] as bool? ?? false,
      firstHourPrice: (json['firstHourPrice'] as num?)?.toDouble() ?? 0,
      additionalHourPrice:
          (json['additionalHourPrice'] as num?)?.toDouble() ?? 0,
      checkinTime: DateTime.parse(json['checkinTime'] as String),
      hasUnpaidServices: json['hasUnpaidServices'] as bool? ?? false,
      unpaidServicesValue:
          (json['unpaidServicesValue'] as num?)?.toDouble() ?? 0,
      validUntil: DateTime.parse(json['validUntil'] as String),
      preCheckin: PreCheckinModel(
        parking: parking,
        plan: PlanType.values.firstWhere(
          (value) => value.name == planName,
          orElse: () => PlanType.hourly,
        ),
        carWash: json['carWash'] as bool? ?? false,
        tourGuide: json['tourGuide'] as bool? ?? false,
        transport: json['transport'] as bool? ?? false,
        total: (json['estimatedValue'] as num?)?.toDouble() ?? 0,
        reservationId: json['id'] as String?,
        platformFeeAmount: (json['platformFeeAmount'] as num?)?.toDouble() ?? 0,
        userLocationLat: (json['userLocationLat'] as num?)?.toDouble() ?? 0,
        userLocationLng: (json['userLocationLng'] as num?)?.toDouble() ?? 0,
      ),
    );
  }

  factory ReservationModel.fromApi(Map<String, dynamic> json) {
    final total = (json['final_total'] as num?)?.toDouble() ??
        (json['estimated_total'] as num?)?.toDouble() ?? 0;
    final plan = PlanType.values.firstWhere(
      (value) => value.name == json['pricing_plan'],
      orElse: () => PlanType.hourly,
    );
    final status = json['status'] == 'completed'
        ? ReservationStatus.finished
        : json['status'] == 'expired'
        ? ReservationStatus.expired
        : json['status'] == 'cancelled'
        ? ReservationStatus.cancelled
        : ReservationStatus.open;
    final parking = ParkingModel(
      id: json['parking_id'] as String,
      name: json['parking_name'] as String? ?? 'Estacionamento',
      city: json['parking_city'] as String? ?? '',
      lat: (json['parking_lat'] as num?)?.toDouble() ?? 0,
      lng: (json['parking_lng'] as num?)?.toDouble() ?? 0,
      rating: 0,
      availableSpots: (json['available_spots'] as num?)?.toInt() ?? 0,
      pricing: ParkingPricing(
        firstHourPrice: (json['base_amount'] as num?)?.toDouble() ?? 0,
        additionalHourPrice: 0,
        dailyPrice: total,
        monthlyPrice: total,
      ),
      hasCarWash: false,
      hasTourGuide: json['guide_user_id'] != null,
      hasTransportService: false,
      carWashPrice: 0,
      tourGuidePrice: 0,
      transportPrice: 0,
      hasCoveredArea: false,
      hasVipSpots: false,
    );
    final created = DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now();
    final expires = DateTime.tryParse(json['hold_expires_at'] as String? ?? '') ?? created.add(const Duration(hours: 12));
    return ReservationModel(
      id: json['id'] as String,
      parkingName: parking.name,
      plan: plan,
      status: status,
      checkinAt: DateTime.tryParse(json['checked_in_at'] as String? ?? '') ?? created,
      checkoutAt: DateTime.tryParse(json['checked_out_at'] as String? ?? ''),
      estimatedValue: total,
      finalValue: (json['final_total'] as num?)?.toDouble(),
      carWash: false,
      tourGuide: json['guide_user_id'] != null,
      transport: false,
      firstHourPrice: (json['base_amount'] as num?)?.toDouble() ?? 0,
      additionalHourPrice: 0,
      checkinTime: created,
      hasUnpaidServices: false,
      unpaidServicesValue: 0,
      validUntil: expires,
      preCheckin: PreCheckinModel(
        parking: parking,
        plan: plan,
        carWash: false,
        tourGuide: json['guide_user_id'] != null,
        transport: false,
        total: total,
        reservationId: json['id'] as String,
        userLocationLat: 0,
        userLocationLng: 0,
      ),
      checkedIn: json['checked_in_at'] != null,
    );
  }
}
