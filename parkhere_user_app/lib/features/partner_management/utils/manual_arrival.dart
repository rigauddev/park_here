DateTime manualArrival({
  required DateTime now,
  required int hour,
  required int minute,
}) {
  final arrival = DateTime(now.year, now.month, now.day, hour, minute);
  final currentMinute = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
  );
  return arrival.isBefore(currentMinute)
      ? DateTime(now.year, now.month, now.day + 1, hour, minute)
      : arrival;
}
