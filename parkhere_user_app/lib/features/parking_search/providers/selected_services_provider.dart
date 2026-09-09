// import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class SelectedServices {
  final bool carWash;
  final bool tourGuide;
  final bool transport;

  SelectedServices({
    this.carWash = false,
    this.tourGuide = false,
    this.transport = false,
  });

  SelectedServices copyWith({bool? carWash, bool? tourGuide, bool? transport}) {
    return SelectedServices(
      carWash: carWash ?? this.carWash,
      tourGuide: tourGuide ?? this.tourGuide,
      transport: transport ?? this.transport,
    );
  }
}

/// Provider global
final selectedServicesProvider = StateProvider<SelectedServices>(
  (ref) => SelectedServices(),
);
