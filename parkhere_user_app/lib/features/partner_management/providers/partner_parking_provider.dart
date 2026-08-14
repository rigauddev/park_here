import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/managed_parking_model.dart';

final partnerParkingProvider =
    AsyncNotifierProvider<PartnerParkingNotifier, List<ManagedParkingModel>>(
      PartnerParkingNotifier.new,
    );

class PartnerParkingNotifier extends AsyncNotifier<List<ManagedParkingModel>> {
  final _api = ApiService();

  @override
  Future<List<ManagedParkingModel>> build() async {
    return fetch();
  }

  Future<List<ManagedParkingModel>> fetch() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return [];

    final data = await _api.getAuthorized(
      '/partners/parking-management',
      token,
    );
    return [
      for (final item in data)
        ManagedParkingModel.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> save(ManagedParkingModel parking) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) {
      throw Exception('Sessao expirada. Entre novamente.');
    }

    if (parking.id == null) {
      await _api.postAuthorized(
        '/partners/parking-management',
        parking.toJson(),
        token,
      );
    } else {
      await _api.putAuthorized(
        '/partners/parking-management/${parking.id}',
        parking.toJson(),
        token,
      );
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(fetch);
  }
}
