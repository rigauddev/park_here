import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pre_reservation_model.dart';

final preReservationProvider =
    AsyncNotifierProvider<PreReservationNotifier, PreReservationModel?>(
      PreReservationNotifier.new,
    );

class PreReservationNotifier extends AsyncNotifier<PreReservationModel?> {
  Timer? _timer;

  @override
  Future<PreReservationModel?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('parkhere_pre_reservation');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final pre = PreReservationModel.fromJson(data);
      if (pre.active && !pre.isExpired) {
        _startExpirationTimer(
          pre.expiresAt.difference(DateTime.now()).inSeconds,
        );
      } else if (pre.active) {
        final expired = pre.copyWith(active: false);
        state = AsyncData(expired);
        await prefs.setString(
          'parkhere_pre_reservation',
          jsonEncode(expired.toJson()),
        );
        return expired;
      }
      return pre;
    } catch (_) {
      return null;
    }
  }

  Future<void> createPreReservation({
    required String parkingId,
    required String parkingName,
    required int routeMinutes,
    String plan = 'hourly',
    String spotType = 'uncovered',
    double total = 0,
    int availableSpots = 0,
  }) async {
    final now = DateTime.now();
    final expires = now.add(Duration(minutes: routeMinutes + 5));

    final pre = PreReservationModel(
      id: now.millisecondsSinceEpoch.toString(),
      parkingId: parkingId,
      parkingName: parkingName,
      createdAt: now,
      expiresAt: expires,
      active: true,
      plan: plan,
      spotType: spotType,
      total: total,
      availableSpots: availableSpots,
    );

    state = AsyncData(pre);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parkhere_pre_reservation', jsonEncode(pre.toJson()));

    _startExpirationTimer(routeMinutes + 5);
  }

  void _startExpirationTimer(int minutes) {
    _timer?.cancel();

    _timer = Timer(Duration(minutes: minutes), () {
      final current = state.value;

      if (current != null) {
        state = AsyncData(current.copyWith(active: false));
        SharedPreferences.getInstance().then(
          (prefs) => prefs.setString(
            'parkhere_pre_reservation',
            jsonEncode(current.copyWith(active: false).toJson()),
          ),
        );
      }
    });
  }

  void cancelPreReservation() {
    _timer?.cancel();
    state = const AsyncData(null);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.remove('parkhere_pre_reservation'),
    );
  }
}
