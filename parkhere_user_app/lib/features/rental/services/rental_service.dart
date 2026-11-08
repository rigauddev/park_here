import '../../../core/services/api_service.dart';

class RentalService {
  final ApiService _api;
  RentalService([ApiService? api]) : _api = api ?? ApiService();

  Future<List<Map<String, dynamic>>> companies(String token) async {
    final response = await _api.getAuthorized('/rentals/companies', token);
    return response.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createCompany({
    required String name,
    required String token,
    String? address,
    String? cnpj,
    String? parentUnitId,
    String? parentServiceType,
  }) => _api.postAuthorized('/rentals/companies', {
    'name': name,
    if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
    if (cnpj != null && cnpj.trim().isNotEmpty) 'cnpj': cnpj.trim(),
    if (parentUnitId != null) 'parent_unit_id': parentUnitId,
    if (parentServiceType != null) 'parent_service_type': parentServiceType,
  }, token);

  Future<Map<String, dynamic>> uploadCompanyLogo({
    required String companyId,
    required String token,
    required String fileName,
    required List<int> bytes,
  }) => _api.uploadAuthorizedFile(
    '/rentals/companies/$companyId/logo',
    token,
    fileName,
    bytes,
  );

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

  Future<List<Map<String, dynamic>>> groups(
    String companyId,
    String token,
  ) async {
    final response = await _api.getAuthorized(
      '/rentals/companies/$companyId/groups',
      token,
    );
    return response.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> setGroupBlocked({
    required String groupId,
    required String token,
    required bool blocked,
  }) => _api.patchAuthorized(
    '/rentals/groups/$groupId/block?blocked=$blocked',
    const {},
    token,
  );

  Future<List<Map<String, dynamic>>> catalogModels({
    required String make,
    required int year,
    required String vehicleType,
    String? model,
    required String token,
  }) async {
    final query = StringBuffer(
      '/rentals/catalog/models?make=${Uri.encodeQueryComponent(make)}&year=$year&vehicle_type=$vehicleType',
    );
    if (model != null && model.trim().isNotEmpty)
      query.write('&model=${Uri.encodeQueryComponent(model.trim())}');
    final response = await _api.getAuthorized(query.toString(), token);
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

  Future<Map<String, dynamic>> createVehicle({
    required String companyId,
    required String token,
    required String vehicleType,
    required String brand,
    required String model,
    required double pricePerDay,
    int? year,
    String? plate,
    String? groupId,
    List<String> photoUrls = const [],
    Map<String, dynamic> specifications = const {},
    int? manufactureYear,
    String? crlvCode,
    String? renavam,
    String? chassis,
  }) => _api.postAuthorized('/rentals/vehicles', {
    'company_id': companyId,
    if (groupId != null) 'group_id': groupId,
    'vehicle_type': vehicleType,
    'brand': brand.trim(),
    'model': model.trim(),
    'price_per_day': pricePerDay,
    if (year != null) 'year': year,
    if (manufactureYear != null) 'manufacture_year': manufactureYear,
    if (plate != null && plate.trim().isNotEmpty) 'plate': plate.trim(),
    if (crlvCode != null && crlvCode.trim().isNotEmpty)
      'crlv_code': crlvCode.trim(),
    if (renavam != null && renavam.trim().isNotEmpty) 'renavam': renavam.trim(),
    if (chassis != null && chassis.trim().isNotEmpty) 'chassis': chassis.trim(),
    'photo_urls': photoUrls,
    'specifications': specifications,
  }, token);

  Future<Map<String, dynamic>> updateVehicle({
    required String vehicleId,
    required String token,
    String? groupId,
    String? vehicleType,
    String? brand,
    String? model,
    double? pricePerDay,
    int? year,
    int? manufactureYear,
    String? plate,
    String? crlvCode,
    String? renavam,
    String? chassis,
    List<String>? photoUrls,
    Map<String, dynamic>? specifications,
  }) => _api.patchAuthorized('/rentals/vehicles/$vehicleId', {
    if (groupId != null) 'group_id': groupId,
    if (vehicleType != null) 'vehicle_type': vehicleType,
    if (brand != null) 'brand': brand.trim(),
    if (model != null) 'model': model.trim(),
    if (pricePerDay != null) 'price_per_day': pricePerDay,
    if (year != null) 'year': year,
    if (manufactureYear != null) 'manufacture_year': manufactureYear,
    if (plate != null) 'plate': plate.trim(),
    if (crlvCode != null) 'crlv_code': crlvCode.trim(),
    if (renavam != null) 'renavam': renavam.trim(),
    if (chassis != null) 'chassis': chassis.trim(),
    if (photoUrls != null) 'photo_urls': photoUrls,
    if (specifications != null) 'specifications': specifications,
  }, token);

  Future<Map<String, dynamic>> uploadCrlv({
    required String vehicleId,
    required String token,
    required String fileName,
    required List<int> bytes,
  }) => _api.uploadAuthorizedFile(
    '/rentals/vehicles/$vehicleId/documents/crlv',
    token,
    fileName,
    bytes,
  );

  Future<Map<String, dynamic>> uploadVehiclePhoto({
    required String vehicleId,
    required String token,
    required String fileName,
    required List<int> bytes,
  }) => _api.uploadAuthorizedFile(
    '/rentals/vehicles/$vehicleId/photos',
    token,
    fileName,
    bytes,
  );

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

  Future<List<Map<String, dynamic>>> items(
    String companyId,
    String token,
  ) async {
    final response = await _api.getAuthorized(
      '/rentals/companies/$companyId/items',
      token,
    );
    return response.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> contract(String reservationId, String token) =>
      _api.getAuthorizedMap(
        '/rentals/reservations/$reservationId/contract',
        token,
      );

  Future<Map<String, dynamic>> acceptContract({
    required String reservationId,
    required String role,
    required String token,
  }) => _api.postAuthorized(
    '/rentals/reservations/$reservationId/contract/accept',
    {'role': role},
    token,
  );

  Future<List<Map<String, dynamic>>> fines(String token) async {
    final response = await _api.getAuthorized('/rentals/fines', token);
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
