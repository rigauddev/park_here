// Modelo de veículo para o módulo de locação
class Vehicle {
  final String id;
  final String companyId;
  final String model;
  final String brand;
  final double pricePerDay;
  final String status;
  final String vehicleType;

  Vehicle({
    required this.id,
    required this.companyId,
    required this.model,
    required this.brand,
    required this.pricePerDay,
    required this.status,
    required this.vehicleType,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: json['id'] as String,
    companyId: json['company_id'] as String,
    model: json['model'] as String,
    brand: json['brand'] as String,
    pricePerDay: (json['price_per_day'] as num).toDouble(),
    status: json['status'] as String,
    vehicleType: json['vehicle_type'] as String? ?? 'car',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'company_id': companyId,
    'model': model,
    'brand': brand,
    'price_per_day': pricePerDay,
    'status': status,
    'vehicle_type': vehicleType,
  };
}
