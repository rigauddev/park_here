import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/partner_profile_model.dart';

final partnerProfileProvider =
    AsyncNotifierProvider<PartnerProfileNotifier, PartnerProfileModel>(
      PartnerProfileNotifier.new,
    );

class PartnerProfileNotifier extends AsyncNotifier<PartnerProfileModel> {
  final _api = ApiService();

  @override
  Future<PartnerProfileModel> build() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) {
      throw Exception('Sessao expirada. Entre novamente.');
    }

    final data = await _api.getAuthorizedMap('/partners/me', token);
    return PartnerProfileModel.fromJson(data);
  }
}
