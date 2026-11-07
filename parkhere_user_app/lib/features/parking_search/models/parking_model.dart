import 'parking_pricing.dart';

class ParkingModel {
  final String id;
  final String name;
  final String city;
  final double lat;
  final double lng;
  final double rating;
  final int availableSpots;
  final int coveredSpots,
      uncoveredSpots,
      vipSpots,
      largeSpots,
      busSpots,
      pickupSpots,
      motoHomeSpots;

  // ✅ Precificação completa
  final ParkingPricing pricing;
  final Map<String, ParkingPricing> categoryPricing;

  // Serviços adicionais
  final bool hasCarWash;
  final bool hasTourGuide;
  final bool hasTransportService;
  final bool hasCoveredArea;
  final bool hasVipSpots;
  final bool isOpen;
  final Map<String, dynamic> operatingHours;

  final double carWashPrice;
  final double tourGuidePrice;
  final double transportPrice;

  ParkingModel({
    required this.id,
    required this.name,
    required this.city,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.availableSpots,
    this.coveredSpots = 0,
    this.uncoveredSpots = 0,
    this.vipSpots = 0,
    this.largeSpots = 0,
    this.busSpots = 0,
    this.pickupSpots = 0,
    this.motoHomeSpots = 0,
    required this.pricing,
    this.categoryPricing = const {},
    required this.hasCarWash,
    required this.hasTourGuide,
    required this.hasTransportService,
    required this.carWashPrice,
    required this.tourGuidePrice,
    required this.transportPrice,
    required this.hasCoveredArea,
    required this.hasVipSpots,
    this.isOpen = true,
    this.operatingHours = const {},
  });

  factory ParkingModel.fromJson(Map<String, dynamic> json) {
    return ParkingModel(
      id: json["id"],
      name: json["name"],
      city: json["city"] as String? ?? "Valenca",
      lat: (json["lat"] as num).toDouble(),
      lng: (json["lng"] as num).toDouble(),
      rating: (json["rating"] as num).toDouble(),
      availableSpots: json["availableSpots"],
      coveredSpots: json["coveredSpots"] ?? 0,
      uncoveredSpots: json["uncoveredSpots"] ?? 0,
      vipSpots: json["vipSpots"] ?? 0,
      largeSpots: json["largeSpots"] ?? 0,
      busSpots: json["busSpots"] ?? 0,
      pickupSpots: json["pickupSpots"] ?? 0,
      motoHomeSpots: json["motoHomeSpots"] ?? 0,
      hasCoveredArea: json["hasCoveredArea"],
      hasVipSpots: json["hasVipSpots"],
      isOpen: json["isOpen"] as bool? ?? true,
      operatingHours: json["operating_hours"] as Map<String, dynamic>? ?? const {},
      hasCarWash: json["hasCarWash"],
      hasTourGuide: json["hasTourGuide"],
      hasTransportService: json["hasTransportService"],
      carWashPrice: (json["carWashPrice"] as num).toDouble(),
      tourGuidePrice: (json["tourGuidePrice"] as num).toDouble(),
      transportPrice: (json["transportPrice"] as num).toDouble(),
      pricing: ParkingPricing.fromJson(json["pricing"]),
      categoryPricing: (json['category_pricing'] as Map<String, dynamic>? ?? {})
          .map(
            (key, value) => MapEntry(
              key,
              ParkingPricing.fromCategoryJson(value as Map<String, dynamic>),
            ),
          ),
    );
  }
}
