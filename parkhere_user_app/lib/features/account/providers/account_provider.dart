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

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final setupDone = prefs.getBool(_setupDoneKey) ?? false;
    final walletDone = prefs.getBool(_walletDoneKey) ?? false;

    if (!setupDone && !walletDone) return;

    state = AccountState(
      driverDocument: setupDone
          ? const DriverDocumentModel(
              type: DriverDocumentType.cnh,
              number: 'CNH123456789',
              frontFileName: 'cnh-frente.jpg',
              backFileName: 'cnh-verso.jpg',
            )
          : null,
      vehicles: setupDone
          ? const [
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
            ]
          : const [],
      walletMethods: walletDone
          ? const [
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
            ]
          : const [],
    );
  }

  Future<void> saveDriverDocument(DriverDocumentModel document) async {
    state = state.copyWith(driverDocument: document);
    await _persistSetupIfComplete();
  }

  Future<void> addVehicle(VehicleModel vehicle) async {
    final updated = [
      for (final current in state.vehicles)
        current.copyWith(isActive: vehicle.isActive ? false : current.isActive),
      vehicle,
    ];

    state = state.copyWith(vehicles: updated);
    await _persistSetupIfComplete();
  }

  Future<void> setActiveVehicle(String vehicleId) async {
    state = state.copyWith(
      vehicles: [
        for (final vehicle in state.vehicles)
          vehicle.copyWith(isActive: vehicle.id == vehicleId),
      ],
    );
    await _persistSetupIfComplete();
  }

  Future<void> addWalletMethod(WalletMethodModel method) async {
    final updated = [
      for (final current in state.walletMethods)
        current.copyWith(isActive: method.isActive ? false : current.isActive),
      method,
    ];

    state = state.copyWith(walletMethods: updated);

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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_walletDoneKey, state.hasActivePaymentMethod);
  }

  Future<void> _persistSetupIfComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupDoneKey, state.canAccessParkingSearch);
  }
}
