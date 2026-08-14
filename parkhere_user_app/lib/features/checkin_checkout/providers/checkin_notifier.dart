import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../parking_search/models/parking_model.dart';
import '../../parking_search/models/payment_plan_enum.dart';
import '../../../core/services/parking_price_calculator.dart';
import '../models/parking_session_model.dart';

final checkinProvider =
    AsyncNotifierProvider<CheckinNotifier, ParkingSessionModel?>(
      CheckinNotifier.new,
    );

class CheckinNotifier extends AsyncNotifier<ParkingSessionModel?> {
  @override
  Future<ParkingSessionModel?> build() async {
    return null; // começa sem sessão ativa
  }

  // ===============================
  // ✅ CHECK-IN
  // ===============================
  Future<void> checkIn({
    required ParkingModel parking,
    required PlanType plan,
    required double estimatedTotal,
  }) async {
    state = const AsyncLoading();

    try {
      final now = DateTime.now();

      // Criar sessão
      final session = ParkingSessionModel(
        sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
        parkingId: parking.id,
        plan: plan,
        checkInTime: now,
        estimatedTotal: estimatedTotal,
      );

      // Simulação backend delay
      await Future.delayed(const Duration(seconds: 1));

      state = AsyncData(session);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  // ===============================
  // ✅ CHECKOUT
  // ===============================
  Future<void> checkout({required ParkingModel parking}) async {
    final session = state.value;
    if (session == null) return;

    state = const AsyncLoading();

    try {
      final now = DateTime.now();

      // Plano mensal = assinatura → valor fixo
      double totalFinal;

      if (session.plan == PlanType.monthly) {
        totalFinal = parking.pricing.monthlyPrice;
      } else {
        totalFinal = ParkingPriceCalculator.calculateTotal(
          parking: parking,
          plan: session.plan,
          checkInTime: session.checkInTime,
          checkOutTime: now,
        );
      }

      final updated = session.copyWith(
        checkOutTime: now,
        finalTotal: totalFinal,
      );

      await Future.delayed(const Duration(seconds: 1));

      state = AsyncData(updated);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  // ===============================
  // ✅ RESET Sessão
  // ===============================
  void resetSession() {
    state = const AsyncData(null);
  }
}
