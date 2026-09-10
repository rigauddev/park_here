import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/partner_operator_model.dart';

final partnerOperatorsProvider =
    AsyncNotifierProvider<PartnerOperatorsNotifier, List<PartnerOperatorModel>>(
      PartnerOperatorsNotifier.new,
    );

class PartnerOperatorsNotifier
    extends AsyncNotifier<List<PartnerOperatorModel>> {
  final _api = ApiService();

  @override
  Future<List<PartnerOperatorModel>> build() async {
    return fetch();
  }

  Future<List<PartnerOperatorModel>> fetch() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) throw Exception('Sessao expirada. Entre novamente.');

    final data = await _api.getAuthorized('/partners/operators', token);
    return [
      for (final item in data)
        PartnerOperatorModel.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> createOperator({
    required String name,
    required String email,
    required String phone,
    required String password,
    required bool acceptedTerms,
    required List<String> permissions,
  }) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) throw Exception('Sessao expirada. Entre novamente.');

    await _api.postAuthorized('/partners/operators', {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'accepted_terms': acceptedTerms,
      'permissions': permissions,
    }, token);

    state = const AsyncLoading();
    state = await AsyncValue.guard(fetch);
  }

  Future<void> assignParkings(String operatorId, List<String> parkingIds) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) throw Exception('Sessão expirada.');
    await _api.putAuthorized('/partners/operators/$operatorId/parkings', {'parking_ids': parkingIds}, token);
  }

  Future<List<String>> fetchOperatorParkings(String operatorId) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) throw Exception('Sessão expirada.');
    final data = await _api.getAuthorized('/partners/operators/$operatorId/parkings', token);
    return data.cast<String>();
  }

  Future<void> createShift({String? operatorId, required String parkingId, required DateTime startsAt, required DateTime endsAt}) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) throw Exception('Sessão expirada.');
    await _api.postAuthorized('/partners/shifts', {'operator_id': operatorId, 'parking_id': parkingId, 'starts_at': startsAt.toUtc().toIso8601String(), 'ends_at': endsAt.toUtc().toIso8601String()}, token);
  }

  Future<Map<String, dynamic>> suggestShifts({required String parkingId, required List<String> operatorIds, required DateTime startsOn, required DateTime endsOn, double dailyHours = 8}) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) throw Exception('Sessão expirada.');
    final response = await _api.postAuthorized('/partners/shifts/suggest', {
      'parking_id': parkingId, 'operator_ids': operatorIds, 'starts_on': startsOn.toUtc().toIso8601String(), 'ends_on': endsOn.toUtc().toIso8601String(), 'daily_hours': dailyHours,
    }, token);
    return response;
  }

  Future<List<Map<String, dynamic>>> fetchShifts() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) throw Exception('Sessão expirada.');
    final data = await _api.getAuthorized('/partners/shifts', token);
    return data.cast<Map<String, dynamic>>();
  }
}
