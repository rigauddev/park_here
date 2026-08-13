import 'package:flutter_riverpod/flutter_riverpod.dart';

final checkinProvider =
    AsyncNotifierProvider<CheckinNotifier, bool>(CheckinNotifier.new);

class CheckinNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return false;
  }

  Future<void> performCheckin() async {
    state = const AsyncLoading();

    // depois: validar GPS + backend
    await Future.delayed(const Duration(seconds: 1));

    state = const AsyncData(true);
  }
}

final checkinStateProvider = Provider<bool>((ref) {
  return ref.watch(checkinProvider).value ?? false;
});