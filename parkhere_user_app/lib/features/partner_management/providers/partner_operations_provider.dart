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

Future<Map<String, dynamic>> createOperationalReservation({
  required String token,
  required String parkingId,
  required String spotCode,
  required String spotType,
  required String pricingPlan,
  required int durationHours,
  required DateTime arrivalEstimateAt,
}) async {
  return ApiService().postAuthorized('/reservations/pre-checkin', {
    'parking_id': parkingId,
    'route_minutes': 1,
    'spot_code': spotCode,
    'spot_type': spotType,
    'arrival_estimate_at': arrivalEstimateAt.toIso8601String(),
    'is_manual_arrival': true,
    'pricing_plan': pricingPlan,
    'duration_hours': durationHours,
    'service_codes': <String>[],
  }, token);
}

Future<void> cancelOperationalReservation({
  required String token,
  required String reservationId,
  required String reason,
}) async {
  await ApiService().postAuthorized('/reservations/$reservationId/cancel', {
    'reason': reason,
  }, token);
}

Future<Map<String, dynamic>> createOperationalPaymentIntent({
  required String token,
  required String reservationId,
  required String method,
}) async {
  return ApiService().postAuthorized(
    '/payments/reservations/$reservationId/intent',
    {'method': method},
    token,
  );
}

Future<void> confirmOperationalPayment({
  required String token,
  required String paymentId,
}) async {
  await ApiService().postAuthorized('/payments/$paymentId/confirm', {}, token);
}

Future<void> checkinOperationalReservation({
  required String token,
  required String reservationId,
}) async {
  await ApiService().postAuthorized(
    '/reservations/$reservationId/checkin',
    {},
    token,
  );
}

Future<void> checkoutOperationalReservation({
  required String token,
  required String reservationId,
}) async {
  await ApiService().postAuthorized(
    '/reservations/$reservationId/checkout',
    {},
    token,
  );
}
