class PreReservationModel {
  final String id;
  final String parkingId;
  final String parkingName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool active;

  PreReservationModel({
    required this.id,
    required this.parkingId,
    required this.parkingName,
    required this.createdAt,
    required this.expiresAt,
    required this.active,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  PreReservationModel copyWith({bool? active}) {
    return PreReservationModel(
      id: id,
      parkingId: parkingId,
      parkingName: parkingName,
      createdAt: createdAt,
      expiresAt: expiresAt,
      active: active ?? this.active,
    );
  }
}
