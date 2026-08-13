import 'package:flutter_riverpod/flutter_riverpod.dart';

final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);

class SubscriptionState {
  final bool active;
  final DateTime? expiresAt;

  const SubscriptionState({
    required this.active,
    this.expiresAt,
  });
}

class SubscriptionNotifier extends AsyncNotifier<SubscriptionState> {
  @override
  Future<SubscriptionState> build() async {
    return const SubscriptionState(active: false);
  }

  /// ✅ Ativa assinatura por 30 dias
  Future<void> activateMonthly() async {
    state = const AsyncLoading();

    final expiration = DateTime.now().add(const Duration(days: 30));

    state = AsyncData(
      SubscriptionState(
        active: true,
        expiresAt: expiration,
      ),
    );
  }

  /// ✅ Verifica se ainda está válida
  bool isValid() {
    final data = state.value;
    if (data == null || !data.active) return false;

    return DateTime.now().isBefore(data.expiresAt!);
  }

  /// Reset
  void cancel() {
    state = const AsyncData(
      SubscriptionState(active: false),
    );
  }
}
