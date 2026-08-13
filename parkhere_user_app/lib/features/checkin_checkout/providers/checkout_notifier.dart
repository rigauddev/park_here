


import 'package:flutter_riverpod/legacy.dart';

import '../../reservation/models/reservation_enum.dart';
import '../../reservation/models/reservation_model.dart';
import '../services/checkout_service.dart';
import 'checkout_privider.dart';

class CheckoutNotifier extends StateNotifier<CheckoutState> {
  CheckoutNotifier() : super(const CheckoutState());

  ReservationModel? _currentReservation;

  Future<void> validate(ReservationModel reservation) async {

    _currentReservation = reservation;

    state = state.copyWith(status: CheckoutStatus.validating);

    try {

      final result = CheckoutService.calculate(reservation);

      if (result > 0) {
        state = state.copyWith(
          status: CheckoutStatus.requiresPayment,
          amount: result,
        );
      } else {
        state = state.copyWith(
          status: CheckoutStatus.generatingQr,
        );
      }

    } catch (e) {
      state = state.copyWith(
        status: CheckoutStatus.error,
        error: e.toString(),
      );
    }
  }

  void paymentSuccess() {
    if (_currentReservation == null) return;

    final updated = _currentReservation!.copyWith(
      hasUnpaidServices: false,
      unpaidServicesValue: 0,
      finalValue: state.amount,
      status: ReservationStatus.finished,
      checkoutAt: DateTime.now(),
    );

    _currentReservation = updated;

    state = state.copyWith(
      status: CheckoutStatus.generatingQr,
    );
  }

  void complete() {
    state = state.copyWith(status: CheckoutStatus.completed);
  }

  void reset() {
    state = const CheckoutState();
  }
}