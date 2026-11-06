import '../../../core/services/api_service.dart';

class RentalService {
  final ApiService _api;
  RentalService([ApiService? api]) : _api = api ?? ApiService();

  Future<List<Map<String, dynamic>>> companies(String token) async {
    final response = await _api.getAuthorized('/rentals/companies', token);
    return response.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> vehicles(
    String companyId,
    String token,
  ) async {
    final response = await _api.getAuthorized(
      '/rentals/companies/$companyId/vehicles',
      token,
    );
    return response.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> plans(
    String companyId,
    String token,
  ) async {
    final response = await _api.getAuthorized(
      '/rentals/companies/$companyId/plans',
      token,
    );
    return response.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> reserve({
    required String companyId,
    required String vehicleId,
    required DateTime start,
    required DateTime end,
    required String token,
    String? planId,
    Map<String, dynamic>? extras,
    int? kmStart,
  }) {
    return _api.postAuthorized('/rentals/reservations', {
      'company_id': companyId,
      'vehicle_id': vehicleId,
      if (planId != null) 'plan_id': planId,
      'start_date': start.toUtc().toIso8601String(),
      'end_date': end.toUtc().toIso8601String(),
      if (extras != null) 'extras': extras,
      if (kmStart != null) 'km_start': kmStart,
    }, token);
  }

  Future<List<Map<String, dynamic>>> maintenance(
    String vehicleId,
    String token,
  ) async {
    final response = await _api.getAuthorized(
      '/rentals/vehicles/$vehicleId/maintenance',
      token,
    );
    return response.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> reservations(String token) async {
    final response = await _api.getAuthorized('/rentals/reservations', token);
    return response.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> checkin({
    required String reservationId,
    required String token,
    int? km,
    List<String> photos = const [],
    Map<String, dynamic>? items,
    String? notes,
  }) => _api.postAuthorized('/rentals/checkin', {
    'reservation_id': reservationId,
    if (km != null) 'km': km,
    'photos': photos,
    if (items != null) 'items': items,
    if (notes != null) 'notes': notes,
  }, token);

  Future<Map<String, dynamic>> checkout({
    required String reservationId,
    required String token,
    int? km,
    List<String> photos = const [],
    Map<String, dynamic>? items,
    String? notes,
    double damageFine = 0,
  }) => _api.postAuthorized('/rentals/checkout', {
    'reservation_id': reservationId,
    if (km != null) 'km': km,
    'photos': photos,
    if (items != null) 'items': items,
    if (notes != null) 'notes': notes,
    'damage_fine': damageFine,
  }, token);
}
