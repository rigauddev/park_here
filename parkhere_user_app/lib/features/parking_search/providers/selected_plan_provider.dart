// import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/payment_plan_enum.dart';

final selectedPlanProvider = StateProvider<PlanType?>((ref) => null);
final selectedDailyDaysProvider = StateProvider<int>((ref) => 1);
final selectedDailyPeriodProvider = StateProvider<DateTimeRange?>(
  (ref) => null,
);

/// Arrival chosen by the customer when a unit is currently closed.  It is
/// kept separate from the route estimate so the backend can validate the
/// requested date and opening hours.
final selectedArrivalEstimateProvider = StateProvider<DateTime?>((ref) => null);
