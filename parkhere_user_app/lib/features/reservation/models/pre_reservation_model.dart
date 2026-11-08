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

  factory PreReservationModel.fromApi(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now();
    final expires = DateTime.tryParse(json['hold_expires_at'] as String? ?? '') ??
        created.add(const Duration(minutes: 5));
    return PreReservationModel(
      id: json['id'] as String,
      parkingId: json['parking_id'] as String? ?? '',
      parkingName: json['parking_name'] as String? ?? 'Estacionamento',
      createdAt: created,
      expiresAt: expires,
      active: json['status'] == 'pre_reserved' ||
          json['status'] == 'pending_operator_approval',
      plan: json['pricing_plan'] as String? ?? 'hourly',
      spotType: json['spot_type'] as String? ?? 'uncovered',
      total: (json['final_total'] as num?)?.toDouble() ??
          (json['estimated_total'] as num?)?.toDouble() ?? 0,
      availableSpots: (json['available_spots'] as num?)?.toInt() ?? 0,
    );
  }

  PreReservationModel copyWith({
    bool? active,
    String? plan,
    String? spotType,
    double? total,
    int? availableSpots,
  }) {
    return PreReservationModel(
      id: id,
      parkingId: parkingId,
      parkingName: parkingName,
      createdAt: createdAt,
      expiresAt: expiresAt,
      active: active ?? this.active,
      plan: plan ?? this.plan,
      spotType: spotType ?? this.spotType,
      total: total ?? this.total,
      availableSpots: availableSpots ?? this.availableSpots,
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
