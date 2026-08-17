import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

class RouteService {
  Future<int> calculateRouteTime({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final meters = Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
    const averageUrbanSpeedMetersPerMinute = 350;
    return math.max(3, (meters / averageUrbanSpeedMetersPerMinute).ceil());
  }
}
