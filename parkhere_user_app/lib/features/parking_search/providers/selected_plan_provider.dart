// import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/payment_plan_enum.dart';

final selectedPlanProvider =
    StateProvider<PlanType?>((ref) => null);
