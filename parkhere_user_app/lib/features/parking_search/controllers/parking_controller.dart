import '../models/parking_model.dart';
import '../models/parking_pricing.dart';

class ParkingController {
  static List<ParkingModel> getNearbyParkings() {
    return [
      ParkingModel(
        id: "1",
        name: "Estacionamento Central",
        lat: -12.9704,
        lng: -38.5124,
        pricing: ParkingPricing(
          firstHourPrice: 10,
          additionalHourPrice: 5,
          dailyPrice: 40,
          monthlyPrice: 300,
        ),
        rating: 4.8,
        availableSpots: 5,
        hasCoveredArea: true,
        hasVipSpots: true,
        hasCarWash: true,
        hasTourGuide: false,
        hasTransportService: false,
        carWashPrice: 5,
        tourGuidePrice: 0,
        transportPrice: 0,
      ),
      ParkingModel(
        id: "2",
        name: "Parking VIP Premium",
        lat: -12.9712,
        lng: -38.5150,
        rating: 4.6,
        availableSpots: 2,
        hasCarWash: true,
        hasTourGuide: true,
        hasTransportService: true,
        carWashPrice: 7,
        tourGuidePrice: 20,
        transportPrice: 10,
        hasCoveredArea: true,
        hasVipSpots: true,
        pricing: ParkingPricing(
          firstHourPrice: 10,
          additionalHourPrice: 5,
          dailyPrice: 40,
          monthlyPrice: 300,
        ),
      ),
    ];
  }
}
