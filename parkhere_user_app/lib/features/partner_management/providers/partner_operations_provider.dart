import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/partner_operational_models.dart';

final partnerParkingMapProvider = FutureProvider<List<PartnerParkingLayout>>((
  ref,
) async {
  final token = ref.read(authProvider).accessToken;
  if (token == null) throw Exception('Sessao expirada. Entre novamente.');

  final data = await ApiService().getAuthorizedMap(
    '/partners/parking-map',
    token,
  );
  return [
    for (final item in data['parkings'] as List<dynamic>)
      PartnerParkingLayout.fromJson(item as Map<String, dynamic>),
  ];
});

final partnerReservationsProvider =
    FutureProvider<List<PartnerReservationSummary>>((ref) async {
      final token = ref.read(authProvider).accessToken;
      if (token == null) throw Exception('Sessao expirada. Entre novamente.');

      final data = await ApiService().getAuthorized(
        '/partners/reservations',
        token,
      );
      return [
        for (final item in data)
          PartnerReservationSummary.fromJson(item as Map<String, dynamic>),
      ];
    });
