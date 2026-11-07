class MapServiceModel {
  final String id;
  final String name;
  final String city;
  final double? lat;
  final double? lng;
  final String serviceType;
  final int availableCount;
  final bool isOpen;

  const MapServiceModel({
    required this.id,
    required this.name,
    required this.city,
    required this.lat,
    required this.lng,
    required this.serviceType,
    required this.availableCount,
    required this.isOpen,
  });

  factory MapServiceModel.fromJson(Map<String, dynamic> json) {
    return MapServiceModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      serviceType: json['service_type']?.toString() ?? 'parking',
      availableCount: (json['available_count'] as num?)?.toInt() ?? 0,
      isOpen: json['is_open'] as bool? ?? true,
    );
  }
}
