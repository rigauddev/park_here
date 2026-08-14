// import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/parking_model.dart';

/// Guarda o texto digitado no campo de busca
final searchQueryProvider = StateProvider<String>((ref) => "");

/// Guarda o texto digitado no campo de busca
final searchResultsProvider = StateProvider<List<ParkingModel>>((ref) => []);
