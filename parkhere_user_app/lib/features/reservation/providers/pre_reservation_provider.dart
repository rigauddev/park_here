import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pre_reservation_model.dart';

final preReservationProvider =
    AsyncNotifierProvider<PreReservationNotifier, PreReservationModel?>(
  PreReservationNotifier.new,
);

class PreReservationNotifier
    extends AsyncNotifier<PreReservationModel?> {

  Timer? _timer;

  @override
  Future<PreReservationModel?> build() async {
    return null;
  }

  Future<void> createPreReservation({
    required String parkingId,
    required String parkingName,
    required int routeMinutes,
  }) async {

    final now = DateTime.now();
    final expires =
        now.add(Duration(minutes: routeMinutes));

    final pre = PreReservationModel(
      id: now.millisecondsSinceEpoch.toString(),
      parkingId: parkingId,
      parkingName: parkingName,
      createdAt: now,
      expiresAt: expires,
      active: true,
    );

    state = AsyncData(pre);

    _startExpirationTimer(routeMinutes);
  }

  void _startExpirationTimer(int minutes) {
    _timer?.cancel();

    _timer = Timer(Duration(minutes: minutes), () {
      final current = state.value;

      if (current != null) {
        state = AsyncData(
          current.copyWith(active: false),
        );
      }
    });
  }

  void cancelPreReservation() {
    _timer?.cancel();
    state = const AsyncData(null);
  }
}
