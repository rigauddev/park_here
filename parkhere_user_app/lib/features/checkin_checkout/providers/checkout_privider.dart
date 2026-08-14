import 'package:flutter_riverpod/legacy.dart';
import 'checkout_notifier.dart';

final checkoutProvider = StateNotifierProvider<CheckoutNotifier, CheckoutState>(
  (ref) => CheckoutNotifier(),
);

enum CheckoutStatus {
  initial,
  validating,
  requiresPayment,
  generatingQr,
  completed,
  error,
}

class CheckoutState {
  final CheckoutStatus status;
  final double? amount;
  final String? error;

  const CheckoutState({
    this.status = CheckoutStatus.initial,
    this.amount,
    this.error,
  });

  CheckoutState copyWith({
    CheckoutStatus? status,
    double? amount,
    String? error,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      amount: amount ?? this.amount,
      error: error,
    );
  }
}
