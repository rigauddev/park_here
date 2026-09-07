import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../parking_search/models/payment_plan_enum.dart';
import '../models/reservation_enum.dart';
import '../models/reservation_model.dart';

final reservationsProvider =
    AsyncNotifierProvider<ReservationsNotifier, List<ReservationModel>>(
      ReservationsNotifier.new,
    );

class ReservationsNotifier extends AsyncNotifier<List<ReservationModel>> {
  @override
  Future<List<ReservationModel>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('parkhere_reservations');
    if (raw == null || raw.isEmpty) return [];
    try {
      final values = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return _applyBusinessRules(
        values.map(ReservationModel.fromJson).toList(),
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> createReservation(ReservationModel reservation) async {
    final current = state.value ?? [];

    final updated = _applyBusinessRules([...current, reservation]);

    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> finishReservation(String id, double finalValue) async {
    final current = state.value ?? [];

    final updated = current.map((r) {
      if (r.id == id) {
        return r.copyWith(
          status: ReservationStatus.finished,
          checkoutAt: DateTime.now(),
          finalValue: finalValue,
        );
      }
      return r;
    }).toList();

    state = AsyncData(_applyBusinessRules(updated));
    await _persist(state.value ?? []);
  }

  Future<void> rateReservation({
    required String id,
    required int parkingRating,
    required int appRating,
    String? comment,
  }) async {
    final current = state.value ?? [];

    final updated = current.map((r) {
      if (r.id == id) {
        return r.copyWith(
          parkingRating: parkingRating,
          appRating: appRating,
          ratingComment: comment,
        );
      }
      return r;
    }).toList();

    state = AsyncData(_applyBusinessRules(updated));
    await _persist(state.value ?? []);
  }

  Future<void> _persist(List<ReservationModel> reservations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'parkhere_reservations',
      jsonEncode(
        reservations.map((reservation) => reservation.toJson()).toList(),
      ),
    );
  }

  // 🔥 REGRA CENTRALIZADA
  List<ReservationModel> _applyBusinessRules(List<ReservationModel> list) {
    return list.map((r) {
      if (r.plan == PlanType.daily && r.status == ReservationStatus.open) {
        final diff = DateTime.now().difference(r.checkinAt);

        if (diff.inHours >= 24) {
          return r.copyWith(status: ReservationStatus.expired);
        }
      }

      return r;
    }).toList();
  }
}
