import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../../core/constants/terms_constants.dart';
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

final partnerFinancialReportProvider =
    FutureProvider<List<PartnerReservationSummary>>((ref) async {
      final token = ref.read(authProvider).accessToken;
      if (token == null) throw Exception('Sessao expirada. Entre novamente.');

      final data = await ApiService().getAuthorized(
        '/partners/financial-report',
        token,
      );
      return [
        for (final item in data)
          PartnerReservationSummary.fromJson(item as Map<String, dynamic>),
      ];
    });

class FinancialFilterParams {
  final int? periodDays;
  final String? startDate;
  final String? endDate;

  const FinancialFilterParams({
    this.periodDays,
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinancialFilterParams &&
          runtimeType == other.runtimeType &&
          periodDays == other.periodDays &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode =>
      periodDays.hashCode ^ startDate.hashCode ^ endDate.hashCode;
}

final partnerFilteredFinancialSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, FinancialFilterParams>((ref, params) async {
      final token = ref.read(authProvider).accessToken;
      if (token == null) throw Exception('Sessao expirada. Entre novamente.');

      final queryParams = <String>[];
      if (params.startDate != null && params.endDate != null) {
        queryParams.add('start_date=${params.startDate}');
        queryParams.add('end_date=${params.endDate}');
      } else if (params.periodDays != null) {
        queryParams.add('period_days=${params.periodDays}');
      }

      final qs = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      return ApiService().getAuthorizedMap(
        '/partners/financial-summary$qs',
        token,
      );
    });

final partnerCostCentersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final token = ref.read(authProvider).accessToken;
      if (token == null) throw Exception('Sessao expirada. Entre novamente.');

      final res = await ApiService().getAuthorized(
        '/partners/financial/cost-centers',
        token,
      );
      return res.whereType<Map<String, dynamic>>().toList();
    });

final partnerFinancialEntriesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, FinancialFilterParams>((ref, params) async {
      final token = ref.read(authProvider).accessToken;
      if (token == null) throw Exception('Sessao expirada. Entre novamente.');

      final queryParams = <String>[];
      if (params.startDate != null && params.endDate != null) {
        queryParams.add('start_date=${params.startDate}');
        queryParams.add('end_date=${params.endDate}');
      }

      final qs = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      final res = await ApiService().getAuthorized(
        '/partners/financial/entries$qs',
        token,
      );
      return res.whereType<Map<String, dynamic>>().toList();
    });

final partnerFinancialSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, periodDays) async {
      final token = ref.read(authProvider).accessToken;
      if (token == null) throw Exception('Sessao expirada. Entre novamente.');

      return ApiService().getAuthorizedMap(
        '/partners/financial-summary?period_days=$periodDays',
        token,
      );
    });

Future<Map<String, dynamic>> createOperationalReservation({
  required String token,
  required String parkingId,
  required String spotCode,
  required String spotType,
  required String pricingPlan,
  required int durationHours,
  required DateTime arrivalEstimateAt,
  required bool arrivalNow,
  required String plate,
  required String ownerPhone,
  required bool termsAccepted,
  required String termsLocale,
}) async {
  return ApiService().postAuthorized('/reservations/pre-checkin', {
    'parking_id': parkingId,
    'terms_accepted': termsAccepted,
    'terms_version': reservationTermsVersion,
    'terms_locale': termsLocale,
    'route_minutes': 1,
    'spot_code': spotCode,
    'spot_type': spotType,
    'arrival_estimate_at': arrivalEstimateAt.toUtc().toIso8601String(),
    'arrival_now': arrivalNow,
    'walk_in_plate': plate,
    'walk_in_phone': ownerPhone,
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

Future<void> reviewArrivalApproval({
  required String token,
  required String reservationId,
  required String decision,
}) async {
  await ApiService().postAuthorized(
    '/reservations/$reservationId/arrival-approval',
    {'decision': decision},
    token,
  );
}

Future<void> toggleParkingSlotBlock({
  required String token,
  required String parkingId,
  required String slotCode,
}) async {
  await ApiService().postAuthorized(
    '/partners/parking-map/$parkingId/slots/$slotCode/block',
    {},
    token,
  );
}

Future<Map<String, dynamic>> createOperationalPaymentIntent({
  required String token,
  required String reservationId,
  required String method,
  String purpose = 'reservation',
  double? cashReceived,
}) async {
  final payment = await ApiService()
      .postAuthorized('/payments/reservations/$reservationId/intent', {
        'method': method,
        'purpose': purpose,
        if (cashReceived != null) 'cash_received': cashReceived,
      }, token);
  if (payment['is_simulated'] != true) {
    throw Exception('Pagamento aguarda confirmação do provedor.');
  }
  return payment;
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

Future<Map<String, dynamic>> fetchCashSession({required String token}) async {
  return ApiService().getAuthorizedMap('/partners/cash-session', token);
}

Future<Map<String, dynamic>> openPartnerCashSession({
  required String token,
  required String parkingId,
  double parkingOpeningCash = 0,
  double convenienceOpeningCash = 0,
}) async {
  return ApiService().postAuthorized('/partners/cash-session', {
    'parking_id': parkingId,
    'parking_opening_cash': parkingOpeningCash,
    'convenience_opening_cash': convenienceOpeningCash,
  }, token);
}

Future<Map<String, dynamic>> closePartnerCashSession({
  required String token,
  double parkingClosingCash = 0,
  double convenienceClosingCash = 0,
  String? closingNotes,
}) async {
  return ApiService().postAuthorized('/partners/cash-session/close', {
    'parking_closing_cash': parkingClosingCash,
    'convenience_closing_cash': convenienceClosingCash,
    if (closingNotes != null && closingNotes.trim().isNotEmpty)
      'closing_notes': closingNotes.trim(),
  }, token);
}

Future<Map<String, dynamic>> createPartnerFinancialEntry({
  required String token,
  required String entryType,
  required String category,
  required String description,
  required double amount,
  required String paymentMethod,
  String? costCenterId,
  String? parkingId,
  String? notes,
  DateTime? entryDate,
}) async {
  return ApiService().postAuthorized('/partners/financial/entries', {
    'entry_type': entryType,
    'category': category,
    'description': description,
    'amount': amount,
    'payment_method': paymentMethod,
    if (costCenterId != null) 'cost_center_id': costCenterId,
    if (parkingId != null) 'parking_id': parkingId,
    if (notes != null && notes.isNotEmpty) 'notes': notes,
    if (entryDate != null) 'entry_date': entryDate.toIso8601String(),
  }, token);
}

Future<Map<String, dynamic>> createPartnerCostCenter({
  required String token,
  required String name,
  String? code,
  String type = 'both',
  String? parkingId,
}) async {
  return ApiService().postAuthorized('/partners/financial/cost-centers', {
    'name': name,
    if (code != null && code.isNotEmpty) 'code': code,
    'type': type,
    if (parkingId != null) 'parking_id': parkingId,
  }, token);
}

Future<void> deactivatePartnerCostCenter({
  required String token,
  required String costCenterId,
}) async {
  await ApiService().deleteAuthorized(
    '/partners/financial/cost-centers/$costCenterId',
    token,
  );
}
