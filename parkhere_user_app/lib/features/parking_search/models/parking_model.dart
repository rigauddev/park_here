import 'parking_pricing.dart';

class ParkingModel {
  final String id;
  final String name;
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
      lat: json["lat"],
      lng: json["lng"],
      rating: json["rating"],
      availableSpots: json["availableSpots"],
      hasCoveredArea: json["hasCoveredArea"],
      hasVipSpots: json["hasVipSpots"],
      hasCarWash: json["hasCarWash"],
      hasTourGuide: json["hasTourGuide"],
      hasTransportService: json["hasTransportService"],
      carWashPrice: json["carWashPrice"],
      tourGuidePrice: json["tourGuidePrice"],
      transportPrice: json["transportPrice"],
      pricing: ParkingPricing.fromJson(json["pricing"]),
      
    );
  }
}
