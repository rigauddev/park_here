import 'package:flutter_test/flutter_test.dart';
import 'package:parkhere_user_app/features/partner_management/utils/manual_arrival.dart';

void main() {
  test('current minute remains today despite seconds elapsed', () {
    expect(
      manualArrival(
        now: DateTime(2026, 9, 6, 10, 30, 59),
        hour: 10,
        minute: 30,
      ),
      DateTime(2026, 9, 6, 10, 30),
    );
  });

  test('future hour remains today', () {
    expect(
      manualArrival(now: DateTime(2026, 9, 6, 10, 30), hour: 11, minute: 0),
      DateTime(2026, 9, 6, 11),
    );
  });

  test('past hour rolls over the year correctly', () {
    expect(
      manualArrival(now: DateTime(2026, 12, 31, 23, 30), hour: 0, minute: 15),
      DateTime(2027, 1, 1, 0, 15),
    );
  });
}
