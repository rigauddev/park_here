import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_models.dart';

final accountProvider = StateNotifierProvider<AccountNotifier, AccountState>(
  (ref) => AccountNotifier(),
);

class AccountState {
  final DriverDocumentModel? driverDocument;
  final List<VehicleModel> vehicles;
  final List<WalletMethodModel> walletMethods;

  const AccountState({
    this.driverDocument,
    this.vehicles = const [],
    this.walletMethods = const [],
  });

  bool get hasActiveVehicle => vehicles.any((vehicle) => vehicle.isActive);
  bool get hasActivePaymentMethod =>
      walletMethods.any((method) => method.isActive);
  bool get canAccessParkingSearch => driverDocument != null && hasActiveVehicle;

  VehicleModel? get activeVehicle {
    for (final vehicle in vehicles) {
      if (vehicle.isActive) return vehicle;
    }
    return null;
  }

  WalletMethodModel? get activePaymentMethod {
    for (final method in walletMethods) {
      if (method.isActive) return method;
    }
    return null;
  }

  AccountState copyWith({
    DriverDocumentModel? driverDocument,
    List<VehicleModel>? vehicles,
    List<WalletMethodModel>? walletMethods,
  }) {
    return AccountState(
      driverDocument: driverDocument ?? this.driverDocument,
      vehicles: vehicles ?? this.vehicles,
      walletMethods: walletMethods ?? this.walletMethods,
    );
  }
}

class AccountNotifier extends StateNotifier<AccountState> {
  AccountNotifier() : super(const AccountState()) {
    _load();
  }

  static const _setupDoneKey = 'account_setup_done';
  static const _walletDoneKey = 'wallet_setup_done';
  static const _driverDocumentKey = 'account_driver_document';
  static const _vehiclesKey = 'account_vehicles';
  static const _walletMethodsKey = 'account_wallet_methods';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final setupDone = prefs.getBool(_setupDoneKey) ?? false;
    final walletDone = prefs.getBool(_walletDoneKey) ?? false;

    final driverDocumentJson = prefs.getString(_driverDocumentKey);
    final vehiclesJson = prefs.getString(_vehiclesKey);
    final walletJson = prefs.getString(_walletMethodsKey);

    DriverDocumentModel? driverDocument;
    List<VehicleModel> vehicles = const [];
    List<WalletMethodModel> walletMethods = const [];

    if (driverDocumentJson != null && driverDocumentJson.isNotEmpty) {
      final data = jsonDecode(driverDocumentJson) as Map<String, dynamic>;
      driverDocument = DriverDocumentModel(
        type: DriverDocumentType.values.firstWhere(
          (value) => value.name == data['type'],
          orElse: () => DriverDocumentType.cnh,
        ),
        number: data['number'] ?? '',
        frontFileName: data['frontFileName'],
        backFileName: data['backFileName'],
      );
    }

    if (vehiclesJson != null && vehiclesJson.isNotEmpty) {
      final decoded = jsonDecode(vehiclesJson) as List<dynamic>;
      vehicles = decoded
          .map((item) => _vehicleFromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (walletJson != null && walletJson.isNotEmpty) {
      final decoded = jsonDecode(walletJson) as List<dynamic>;
      walletMethods = decoded
          .map((item) => _walletFromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (driverDocument == null && setupDone) {
      driverDocument = const DriverDocumentModel(
        type: DriverDocumentType.cnh,
        number: 'CNH123456789',
        frontFileName: 'cnh-frente.jpg',
        backFileName: 'cnh-verso.jpg',
      );
    }

    if (vehicles.isEmpty && setupDone) {
      vehicles = const [
        VehicleModel(
          id: '00000000-0000-0000-0000-000000000001',
          nickname: 'Meu carro',
          plate: 'PKH1A23',
          brand: 'Toyota',
          model: 'Corolla',
          color: 'Prata',
          documentFileName: 'crlv-2026.pdf',
          ownershipType: VehicleOwnershipType.owner,
          isActive: true,
        ),
      ];
    }

    if (walletMethods.isEmpty && walletDone) {
      walletMethods = const [
        WalletMethodModel(
          id: 'seed-card',
          type: WalletMethodType.creditCard,
          label: 'Visa final 4242',
          holderName: 'Cliente Teste',
          brand: 'Visa',
          lastFour: '4242',
          expiry: '12/30',
          isActive: true,
        ),
      ];
    }

    state = AccountState(
      driverDocument: driverDocument,
      vehicles: vehicles,
      walletMethods: walletMethods,
    );
  }

  Future<void> saveDriverDocument(DriverDocumentModel document) async {
    state = state.copyWith(driverDocument: document);
    await _persistDriverDocument();
    await _persistSetupIfComplete();
  }

  Future<void> addVehicle(VehicleModel vehicle) async {
    final updated = [
      for (final current in state.vehicles)
        current.copyWith(isActive: vehicle.isActive ? false : current.isActive),
      vehicle,
    ];

    state = state.copyWith(vehicles: updated);
    await _persistVehicles();
    await _persistSetupIfComplete();
  }

  Future<void> setActiveVehicle(String vehicleId) async {
    state = state.copyWith(
      vehicles: [
        for (final vehicle in state.vehicles)
          vehicle.copyWith(isActive: vehicle.id == vehicleId),
      ],
    );
    await _persistVehicles();
    await _persistSetupIfComplete();
  }

  Future<void> addWalletMethod(WalletMethodModel method) async {
    final updated = [
      for (final current in state.walletMethods)
        current.copyWith(isActive: method.isActive ? false : current.isActive),
      method,
    ];

    state = state.copyWith(walletMethods: updated);
    await _persistWalletMethods();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_walletDoneKey, state.hasActivePaymentMethod);
  }

  Future<void> setActiveWalletMethod(String methodId) async {
    state = state.copyWith(
      walletMethods: [
        for (final method in state.walletMethods)
          method.copyWith(isActive: method.id == methodId),
      ],
    );
    await _persistWalletMethods();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_walletDoneKey, state.hasActivePaymentMethod);
  }

  Future<void> _persistDriverDocument() async {
    final prefs = await SharedPreferences.getInstance();
    if (state.driverDocument == null) {
      await prefs.remove(_driverDocumentKey);
      return;
    }

    final payload = {
      'type': state.driverDocument!.type.name,
      'number': state.driverDocument!.number,
      'frontFileName': state.driverDocument!.frontFileName,
      'backFileName': state.driverDocument!.backFileName,
    };
    await prefs.setString(_driverDocumentKey, jsonEncode(payload));
  }

  Future<void> _persistVehicles() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = state.vehicles.map(_vehicleToJson).toList();
    await prefs.setString(_vehiclesKey, jsonEncode(payload));
  }

  Future<void> _persistWalletMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = state.walletMethods.map(_walletToJson).toList();
    await prefs.setString(_walletMethodsKey, jsonEncode(payload));
  }

  Future<void> _persistSetupIfComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupDoneKey, state.canAccessParkingSearch);
  }

  Map<String, dynamic> _vehicleToJson(VehicleModel vehicle) {
    return {
      'id': vehicle.id,
      'nickname': vehicle.nickname,
      'plate': vehicle.plate,
      'brand': vehicle.brand,
      'model': vehicle.model,
      'color': vehicle.color,
      'documentFileName': vehicle.documentFileName,
      'ownershipType': vehicle.ownershipType.name,
      'isActive': vehicle.isActive,
    };
  }

  VehicleModel _vehicleFromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] ?? '',
      nickname: json['nickname'] ?? 'Meu carro',
      plate: json['plate'] ?? '',
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      color: json['color'] ?? '',
      documentFileName: json['documentFileName'],
      ownershipType: VehicleOwnershipType.values.firstWhere(
        (value) => value.name == (json['ownershipType'] ?? 'owner'),
        orElse: () => VehicleOwnershipType.owner,
      ),
      isActive: json['isActive'] ?? false,
    );
  }

  Map<String, dynamic> _walletToJson(WalletMethodModel method) {
    return {
      'id': method.id,
      'type': method.type.name,
      'label': method.label,
      'holderName': method.holderName,
      'brand': method.brand,
      'lastFour': method.lastFour,
      'expiry': method.expiry,
      'pixKey': method.pixKey,
      'isActive': method.isActive,
    };
  }

  WalletMethodModel _walletFromJson(Map<String, dynamic> json) {
    return WalletMethodModel(
      id: json['id'] ?? '',
      type: WalletMethodType.values.firstWhere(
        (value) => value.name == (json['type'] ?? 'creditCard'),
        orElse: () => WalletMethodType.creditCard,
      ),
      label: json['label'] ?? 'Metodo',
      holderName: json['holderName'],
      brand: json['brand'],
      lastFour: json['lastFour'],
      expiry: json['expiry'],
      pixKey: json['pixKey'],
      isActive: json['isActive'] ?? false,
    );
  }
}
