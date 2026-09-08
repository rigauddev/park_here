class PreReservationModel {
  final String id;
  final String parkingId;
  final String parkingName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool active;
  final String plan;
  final String spotType;
  final double total;
  final int availableSpots;

  PreReservationModel({
    required this.id,
    required this.parkingId,
    required this.parkingName,
    required this.createdAt,
    required this.expiresAt,
    required this.active,
    this.plan = 'hourly',
    this.spotType = 'uncovered',
    this.total = 0,
    this.availableSpots = 0,
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

  factory PreReservationModel.fromJson(Map<String, dynamic> json) =>
      PreReservationModel(
        id: json['id'] as String,
        parkingId: json['parkingId'] as String,
        parkingName: json['parkingName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        active: json['active'] as bool? ?? false,
        plan: json['plan'] as String? ?? 'hourly',
        spotType: json['spotType'] as String? ?? 'uncovered',
        total: (json['total'] as num?)?.toDouble() ?? 0,
        availableSpots: json['availableSpots'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'parkingId': parkingId,
    'parkingName': parkingName,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
        'active': active,
        'plan': plan,
        'spotType': spotType,
        'total': total,
        'availableSpots': availableSpots,
  };
}
