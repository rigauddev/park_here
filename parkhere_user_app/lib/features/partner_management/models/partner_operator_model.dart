class PartnerOperatorModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final List<String> permissions;
  final bool isActive;
  final DateTime createdAt;

  const PartnerOperatorModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.permissions,
    required this.isActive,
    required this.createdAt,
  });

  factory PartnerOperatorModel.fromJson(Map<String, dynamic> json) {
    return PartnerOperatorModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      permissions: [
        for (final item in (json['permissions'] as List<dynamic>? ?? []))
          item as String,
      ],
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
