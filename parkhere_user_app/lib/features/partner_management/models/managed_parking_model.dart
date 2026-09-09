class ParkingAreaPricingModel {
  final double firstHourPrice;
  final double additionalHourPrice;
  final double dailyPrice;
  final double weeklyPrice;
  final double monthlyPrice;

  const ParkingAreaPricingModel({
    required this.firstHourPrice,
    required this.additionalHourPrice,
    required this.dailyPrice,
    required this.weeklyPrice,
    required this.monthlyPrice,
  });

  factory ParkingAreaPricingModel.fromJson(Map<String, dynamic> json) {
    return ParkingAreaPricingModel(
      firstHourPrice: (json['first_hour_price'] as num).toDouble(),
      additionalHourPrice: (json['additional_hour_price'] as num).toDouble(),
      dailyPrice: (json['daily_price'] as num).toDouble(),
      weeklyPrice: (json['weekly_price'] as num).toDouble(),
      monthlyPrice: (json['monthly_price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first_hour_price': firstHourPrice,
      'additional_hour_price': additionalHourPrice,
      'daily_price': dailyPrice,
      'weekly_price': weeklyPrice,
      'monthly_price': monthlyPrice,
    };
  }
}

class ManagedParkingServiceModel {
  final String? id;
  final String code;
  final String name;
  final double price;
  final bool isActive;

  const ManagedParkingServiceModel({
    this.id,
    required this.code,
    required this.name,
    required this.price,
    required this.isActive,
  });

  factory ManagedParkingServiceModel.fromJson(Map<String, dynamic> json) {
    return ManagedParkingServiceModel(
      id: json['id'] as String?,
      code: json['code'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {'code': code, 'name': name, 'price': price, 'is_active': isActive};
  }
}

class ManagedParkingModel {
  final int arrivalToleranceMinutes;
  final String? id;
  final String name;
  final String address;
  final String city;
  final double lat;
  final double lng;
  final int totalSpots;
  final int availableSpots;
  final int coveredSpots;
  final int uncoveredSpots;
  final int vipSpots;
  final int largeSpots;
  final int busSpots;
  final int pickupSpots;
  final bool hasVipSpots;
  final bool has24hGate;
  final bool hasSecuritySystem;
  final bool wantsAutomaticAccess;
  final bool hasAutomaticAccess;
  final bool isActive;
  final ParkingAreaPricingModel uncoveredPricing;
  final ParkingAreaPricingModel coveredPricing;
  final List<ManagedParkingServiceModel> services;

  const ManagedParkingModel({
    this.arrivalToleranceMinutes = 15,
    this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.lat,
    required this.lng,
    required this.totalSpots,
    required this.availableSpots,
    required this.coveredSpots,
    required this.uncoveredSpots,
    required this.vipSpots,
    required this.largeSpots,
    required this.busSpots,
    required this.pickupSpots,
    required this.hasVipSpots,
    required this.has24hGate,
    required this.hasSecuritySystem,
    required this.wantsAutomaticAccess,
    required this.hasAutomaticAccess,
    required this.isActive,
    required this.uncoveredPricing,
    required this.coveredPricing,
    required this.services,
  });

  factory ManagedParkingModel.fromJson(Map<String, dynamic> json) {
    return ManagedParkingModel(
      arrivalToleranceMinutes: json['arrival_tolerance_minutes'] as int? ?? 15,
      id: json['id'] as String?,
      name: json['name'] as String,
      address: json['address'] as String,
      city: json['city'] as String? ?? 'Valenca',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      totalSpots: json['total_spots'] as int,
      availableSpots: json['available_spots'] as int,
      coveredSpots: json['covered_spots'] as int,
      uncoveredSpots: json['uncovered_spots'] as int,
      vipSpots: json['vip_spots'] as int? ?? 0,
      largeSpots: json['large_spots'] as int? ?? 0,
      busSpots: json['bus_spots'] as int? ?? 0,
      pickupSpots: json['pickup_spots'] as int? ?? 0,
      hasVipSpots: json['has_vip_spots'] as bool? ?? false,
      has24hGate: json['has_24h_gate'] as bool? ?? false,
      hasSecuritySystem: json['has_security_system'] as bool? ?? false,
      wantsAutomaticAccess: json['wants_automatic_access'] as bool? ?? false,
      hasAutomaticAccess: json['has_automatic_access'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      uncoveredPricing: ParkingAreaPricingModel.fromJson(
        json['uncovered_pricing'] as Map<String, dynamic>,
      ),
      coveredPricing: ParkingAreaPricingModel.fromJson(
        json['covered_pricing'] as Map<String, dynamic>,
      ),
      services: [
        for (final service in json['services'] as List<dynamic>)
          ManagedParkingServiceModel.fromJson(service as Map<String, dynamic>),
      ],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'lat': lat,
      'lng': lng,
      'arrival_tolerance_minutes': arrivalToleranceMinutes,
      'total_spots': totalSpots,
      'available_spots': availableSpots,
      'covered_spots': coveredSpots,
      'uncovered_spots': uncoveredSpots,
      'vip_spots': vipSpots,
      'large_spots': largeSpots,
      'bus_spots': busSpots,
      'pickup_spots': pickupSpots,
      'has_vip_spots': hasVipSpots,
      'has_24h_gate': has24hGate,
      'has_security_system': hasSecuritySystem,
      'wants_automatic_access': wantsAutomaticAccess,
      'has_automatic_access': hasAutomaticAccess,
      'uncovered_pricing': uncoveredPricing.toJson(),
      'covered_pricing': coveredPricing.toJson(),
      'services': services.map((service) => service.toJson()).toList(),
      'is_active': isActive,
    };
  }
}
