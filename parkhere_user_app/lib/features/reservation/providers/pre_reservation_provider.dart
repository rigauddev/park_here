import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/local_storage_service.dart';
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

    // A pre-reservation is a server resource. The local copy is only a
    // fallback for offline rendering, so a login on another device can recover
    // the active hold from the authenticated reservations endpoint.
    final token = (await LocalStorageService().getTokens())['access'];
    if (token != null && token.isNotEmpty) {
      try {
        final remote = await ApiService().getAuthorized('/reservations', token);
        final active = remote
            .whereType<Map<String, dynamic>>()
            .where(
              (item) =>
                  item['status'] == 'pre_reserved' ||
                  item['status'] == 'pending_operator_approval',
            )
            .toList();
        if (active.isNotEmpty) {
          active.sort((a, b) =>
              _date(b['created_at']).compareTo(_date(a['created_at'])));
          final item = active.first;
          final remotePre = PreReservationModel.fromApi(item);
          await prefs.setString(
            'parkhere_pre_reservation',
            jsonEncode(remotePre.toJson()),
          );
          if (remotePre.active && !remotePre.isExpired) {
            _startExpirationTimer(
              remotePre.expiresAt.difference(DateTime.now()).inSeconds,
            );
          }
          return remotePre;
        }
        // Remove a stale local hold after the server confirms that none is
        // active anymore (for example after cancellation on another device).
        await prefs.remove('parkhere_pre_reservation');
        return null;
      } catch (_) {
        // Continue with the local cache when the API is temporarily offline.
      }
    }

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

  static DateTime _date(Object? value) =>
      DateTime.tryParse(value as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> createPreReservation({
    required String parkingId,
    required String parkingName,
    required int routeMinutes,
    String? reservationId,
    String plan = 'hourly',
    String spotType = 'uncovered',
    double total = 0,
    int availableSpots = 0,
  }) async {
    final now = DateTime.now();
    final expires = now.add(Duration(minutes: routeMinutes + 5));

    final pre = PreReservationModel(
      id: reservationId ?? now.millisecondsSinceEpoch.toString(),
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

    _startExpirationTimer((routeMinutes + 5) * 60);
  }

  void _startExpirationTimer(int seconds) {
    _timer?.cancel();

    // API hydration uses seconds for the remaining server hold.
    final duration = Duration(seconds: seconds.clamp(0, 365 * 24 * 60 * 60));
    _timer = Timer(duration, () {
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
