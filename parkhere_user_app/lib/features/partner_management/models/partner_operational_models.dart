class PartnerSlotReservation {
  final String id;
  final String status;
  final String paymentStatus;
  final String spotType;
  final String pricingPlan;
  final int durationHours;
  final double baseAmount;
  final double servicesAmount;
  final double platformFeeAmount;
  final double finalTotal;
  final List<PartnerReservationService> selectedServices;
  final String? vehiclePlate;
  final String? vehicleLabel;
  final int routeMinutes;
  final DateTime createdAt;
  final DateTime arrivalEstimateAt;
  final DateTime holdExpiresAt;
  final bool isManualArrival;
  final double cancellationFeeAmount;
  final double cancellationCreditAmount;

  const PartnerSlotReservation({
    required this.id,
    required this.status,
    required this.paymentStatus,
    required this.spotType,
    required this.pricingPlan,
    required this.durationHours,
    required this.baseAmount,
    required this.servicesAmount,
    required this.platformFeeAmount,
    required this.finalTotal,
    required this.selectedServices,
    required this.vehiclePlate,
    required this.vehicleLabel,
    required this.routeMinutes,
    required this.createdAt,
    required this.arrivalEstimateAt,
    required this.holdExpiresAt,
    required this.isManualArrival,
    required this.cancellationFeeAmount,
    required this.cancellationCreditAmount,
  });

  factory PartnerSlotReservation.fromJson(Map<String, dynamic> json) {
    return PartnerSlotReservation(
      id: json['id'] as String,
      status: json['status'] as String,
      paymentStatus: json['payment_status'] as String,
      spotType: json['spot_type'] as String? ?? 'uncovered',
      pricingPlan: json['pricing_plan'] as String? ?? 'hourly',
      durationHours: json['duration_hours'] as int? ?? 1,
      baseAmount: (json['base_amount'] as num? ?? 0).toDouble(),
      servicesAmount: (json['services_amount'] as num? ?? 0).toDouble(),
      platformFeeAmount: (json['platform_fee_amount'] as num? ?? 0).toDouble(),
      finalTotal: (json['final_total'] as num).toDouble(),
      selectedServices: [
        for (final item in json['selected_services'] as List<dynamic>? ?? [])
          PartnerReservationService.fromJson(item as Map<String, dynamic>),
      ],
      vehiclePlate: json['vehicle_plate'] as String?,
      vehicleLabel: json['vehicle_label'] as String?,
      routeMinutes: json['route_minutes'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      arrivalEstimateAt: DateTime.parse(json['arrival_estimate_at'] as String),
      holdExpiresAt: DateTime.parse(json['hold_expires_at'] as String),
      isManualArrival: json['is_manual_arrival'] as bool? ?? false,
      cancellationFeeAmount: (json['cancellation_fee_amount'] as num? ?? 0)
          .toDouble(),
      cancellationCreditAmount:
          (json['cancellation_credit_amount'] as num? ?? 0).toDouble(),
    );
  }
}

class PartnerReservationService {
  final String code;
  final String name;
  final double price;

  const PartnerReservationService({
    required this.code,
    required this.name,
    required this.price,
  });

  factory PartnerReservationService.fromJson(Map<String, dynamic> json) {
    return PartnerReservationService(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? 'Servico',
      price: (json['price'] as num? ?? 0).toDouble(),
    );
  }
}

class PartnerParkingSlot {
  final String code;
  final String type;
  final String status;
  final PartnerSlotReservation? reservation;

  const PartnerParkingSlot({
    required this.code,
    required this.type,
    required this.status,
    required this.reservation,
  });

  factory PartnerParkingSlot.fromJson(Map<String, dynamic> json) {
    final reservationJson = json['reservation'];
    return PartnerParkingSlot(
      code: json['code'] as String,
      type: json['type'] as String? ?? 'uncovered',
      status: json['status'] as String,
      reservation: reservationJson is Map<String, dynamic>
          ? PartnerSlotReservation.fromJson(reservationJson)
          : null,
    );
  }
}

class PartnerParkingLayout {
  final String id;
  final String name;
  final int totalSpots;
  final int availableSpots;
  final int preReservedSpots;
  final int occupiedSpots;
  final double preReservedAmount;
  final double confirmedAmount;
  final double checkedInAmount;
  final double pendingPaymentAmount;
  final double paidAmount;
  final Map<String, double> servicesAmountByStatus;
  final List<PartnerParkingSlot> slots;

  const PartnerParkingLayout({
    required this.id,
    required this.name,
    required this.totalSpots,
    required this.availableSpots,
    required this.preReservedSpots,
    required this.occupiedSpots,
    required this.preReservedAmount,
    required this.confirmedAmount,
    required this.checkedInAmount,
    required this.pendingPaymentAmount,
    required this.paidAmount,
    required this.servicesAmountByStatus,
    required this.slots,
  });

  factory PartnerParkingLayout.fromJson(Map<String, dynamic> json) {
    return PartnerParkingLayout(
      id: json['id'] as String,
      name: json['name'] as String,
      totalSpots: json['total_spots'] as int,
      availableSpots: json['available_spots'] as int,
      preReservedSpots: json['pre_reserved_spots'] as int,
      occupiedSpots: json['occupied_spots'] as int,
      preReservedAmount: (json['pre_reserved_amount'] as num? ?? 0).toDouble(),
      confirmedAmount: (json['confirmed_amount'] as num? ?? 0).toDouble(),
      checkedInAmount: (json['checked_in_amount'] as num? ?? 0).toDouble(),
      pendingPaymentAmount: (json['pending_payment_amount'] as num? ?? 0)
          .toDouble(),
      paidAmount: (json['paid_amount'] as num? ?? 0).toDouble(),
      servicesAmountByStatus: {
        for (final entry
            in (json['services_amount_by_status'] as Map<String, dynamic>? ??
                    {})
                .entries)
          entry.key: (entry.value as num? ?? 0).toDouble(),
      },
      slots: [
        for (final item in json['slots'] as List<dynamic>)
          PartnerParkingSlot.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class PartnerReservationSummary {
  final String id;
  final String parkingName;
  final String customerName;
  final String? vehiclePlate;
  final String? vehicleLabel;
  final String status;
  final String paymentStatus;
  final String spotType;
  final String pricingPlan;
  final double baseAmount;
  final double servicesAmount;
  final double platformFeeAmount;
  final double finalTotal;
  final List<PartnerReservationService> selectedServices;
  final DateTime createdAt;
  final DateTime holdExpiresAt;

  const PartnerReservationSummary({
    required this.id,
    required this.parkingName,
    required this.customerName,
    required this.vehiclePlate,
    required this.vehicleLabel,
    required this.status,
    required this.paymentStatus,
    required this.spotType,
    required this.pricingPlan,
    required this.baseAmount,
    required this.servicesAmount,
    required this.platformFeeAmount,
    required this.finalTotal,
    required this.selectedServices,
    required this.createdAt,
    required this.holdExpiresAt,
  });

  factory PartnerReservationSummary.fromJson(Map<String, dynamic> json) {
    return PartnerReservationSummary(
      id: json['id'] as String,
      parkingName: json['parking_name'] as String,
      customerName: json['customer_name'] as String,
      vehiclePlate: json['vehicle_plate'] as String?,
      vehicleLabel: json['vehicle_label'] as String?,
      status: json['status'] as String,
      paymentStatus: json['payment_status'] as String,
      spotType: json['spot_type'] as String,
      pricingPlan: json['pricing_plan'] as String,
      baseAmount: (json['base_amount'] as num? ?? 0).toDouble(),
      servicesAmount: (json['services_amount'] as num? ?? 0).toDouble(),
      platformFeeAmount: (json['platform_fee_amount'] as num? ?? 0).toDouble(),
      finalTotal: (json['final_total'] as num).toDouble(),
      selectedServices: [
        for (final item in json['selected_services'] as List<dynamic>? ?? [])
          PartnerReservationService.fromJson(item as Map<String, dynamic>),
      ],
      createdAt: DateTime.parse(json['created_at'] as String),
      holdExpiresAt: DateTime.parse(json['hold_expires_at'] as String),
    );
  }
}
