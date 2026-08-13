// import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class ParkingFilter {
  final bool covered;
  final bool vip;
  final bool carWash;
  final bool tourGuide;
  final bool transport;

  ParkingFilter({
    this.covered = false,
    this.vip = false,
    this.carWash = false,
    this.tourGuide = false,
    this.transport = false,
  });

  ParkingFilter copyWith({
    bool? covered,
    bool? vip,
    bool? carWash,
    bool? tourGuide,
    bool? transport,
  }) {
    return ParkingFilter(
      covered: covered ?? this.covered,
      vip: vip ?? this.vip,
      carWash: carWash ?? this.carWash,
      tourGuide: tourGuide ?? this.tourGuide,
      transport: transport ?? this.transport,
    );
  }
}

final filterProvider =
    StateProvider<ParkingFilter>((ref) => ParkingFilter());
