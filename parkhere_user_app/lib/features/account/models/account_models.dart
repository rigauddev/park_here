enum DriverDocumentType { cnh, rg }

enum VehicleOwnershipType { owner, rented }

enum WalletMethodType { creditCard, debitCard, pix }

class DriverDocumentModel {
  final DriverDocumentType type;
  final String number;
  final String? frontFileName;
  final String? backFileName;

  const DriverDocumentModel({
    required this.type,
    required this.number,
    this.frontFileName,
    this.backFileName,
  });
}

class VehicleModel {
  final String id;
  final String nickname;
  final String plate;
  final String brand;
  final String model;
  final String color;
  final String? documentFileName;
  final VehicleOwnershipType ownershipType;
  final bool isActive;

  const VehicleModel({
    required this.id,
    required this.nickname,
    required this.plate,
    required this.brand,
    required this.model,
    required this.color,
    this.documentFileName,
    required this.ownershipType,
    required this.isActive,
  });

  VehicleModel copyWith({bool? isActive}) {
    return VehicleModel(
      id: id,
      nickname: nickname,
      plate: plate,
      brand: brand,
      model: model,
      color: color,
      documentFileName: documentFileName,
      ownershipType: ownershipType,
      isActive: isActive ?? this.isActive,
    );
  }
}

class WalletMethodModel {
  final String id;
  final WalletMethodType type;
  final String label;
  final String? holderName;
  final String? brand;
  final String? lastFour;
  final String? expiry;
  final String? pixKey;
  final bool isActive;

  const WalletMethodModel({
    required this.id,
    required this.type,
    required this.label,
    this.holderName,
    this.brand,
    this.lastFour,
    this.expiry,
    this.pixKey,
    required this.isActive,
  });

  WalletMethodModel copyWith({bool? isActive}) {
    return WalletMethodModel(
      id: id,
      type: type,
      label: label,
      holderName: holderName,
      brand: brand,
      lastFour: lastFour,
      expiry: expiry,
      pixKey: pixKey,
      isActive: isActive ?? this.isActive,
    );
  }
}
