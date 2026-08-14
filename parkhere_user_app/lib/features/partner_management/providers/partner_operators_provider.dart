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
  }) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) throw Exception('Sessao expirada. Entre novamente.');

    await _api.postAuthorized('/partners/operators', {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'accepted_terms': acceptedTerms,
    }, token);

    state = const AsyncLoading();
    state = await AsyncValue.guard(fetch);
  }
}
