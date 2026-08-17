import 'parking_pricing.dart';

class ParkingModel {
  final String id;
  final String name;
  final String city;
  final double lat;
  final double lng;
  final double rating;
  final int availableSpots;

  // ✅ Precificação completa
  final ParkingPricing pricing;

  // Serviços adicionais
  final bool hasCarWash;
  final bool hasTourGuide;
  final bool hasTransportService;
  final bool hasCoveredArea;
  final bool hasVipSpots;

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
    required this.pricing,
    required this.hasCarWash,
    required this.hasTourGuide,
    required this.hasTransportService,
    required this.carWashPrice,
    required this.tourGuidePrice,
    required this.transportPrice,
    required this.hasCoveredArea,
    required this.hasVipSpots,
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
      hasCoveredArea: json["hasCoveredArea"],
      hasVipSpots: json["hasVipSpots"],
      hasCarWash: json["hasCarWash"],
      hasTourGuide: json["hasTourGuide"],
      hasTransportService: json["hasTransportService"],
      carWashPrice: (json["carWashPrice"] as num).toDouble(),
      tourGuidePrice: (json["tourGuidePrice"] as num).toDouble(),
      transportPrice: (json["transportPrice"] as num).toDouble(),
      pricing: ParkingPricing.fromJson(json["pricing"]),
    );
  }
}
