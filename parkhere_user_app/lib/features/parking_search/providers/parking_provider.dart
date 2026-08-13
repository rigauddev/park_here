import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/services/api_service.dart';
import '../models/parking_model.dart';
import '../models/parking_pricing.dart';

/// Provider global
final selectedParkingProvider = StateProvider<ParkingModel?>((ref) => null);

/// Provider do serviço central
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

/// AsyncNotifier (lista de estacionamentos)
final parkingProvider =
    AsyncNotifierProvider<ParkingNotifier, List<ParkingModel>>(
      ParkingNotifier.new,
    );

class ParkingNotifier extends AsyncNotifier<List<ParkingModel>> {
  @override
  Future<List<ParkingModel>> build() async {
    return fetchParkings();
  }

  Future<List<ParkingModel>> fetchParkings() async {
    final api = ref.read(apiServiceProvider);

    try {
      final data = await api.get("/parkings");
      return data
          .map((item) => ParkingModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Fallback local para continuar testando o app sem backend.
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return [
      ParkingModel(
        id: "1",
        name: "Estacionamento Central",
        lat: -12.9704,
        lng: -38.5124,
        rating: 4.9,
        availableSpots: 12,
        hasCoveredArea: true,
        hasVipSpots: true,

        pricing: ParkingPricing(
          firstHourPrice: 10,
          additionalHourPrice: 5,
          dailyPrice: 40,
          monthlyPrice: 300,
        ),

        hasCarWash: true,
        hasTourGuide: true,
        hasTransportService: false,

        carWashPrice: 30,
        tourGuidePrice: 50,
        transportPrice: 0,
      ),

      ParkingModel(
        id: "2",
        name: "Estacionamento VIP",
        lat: -12.9712,
        lng: -38.5150,
        rating: 4.6,
        availableSpots: 5,

        pricing: ParkingPricing(
          firstHourPrice: 20,
          additionalHourPrice: 10,
          dailyPrice: 80,
          monthlyPrice: 600,
        ),

        hasCoveredArea: true,
        hasVipSpots: true,
        hasCarWash: true,
        hasTourGuide: true,
        hasTransportService: true,
        carWashPrice: 50,
        tourGuidePrice: 100,
        transportPrice: 50,
      ),
    ];

    // Quando backend estiver pronto:
    /*
    final data = await api.get("/parkings");

    return data.map((e) => ParkingModel.fromJson(e)).toList();
    */
  }
}
