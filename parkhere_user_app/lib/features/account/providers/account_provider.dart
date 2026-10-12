import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/local_storage_service.dart';
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

  final _api = ApiService();
  final _storage = LocalStorageService();

  static const _setupDoneKey = 'account_setup_done';
  static const _walletDoneKey = 'wallet_setup_done';
  static const _driverDocumentKey = 'account_driver_document';
  static const _vehiclesKey = 'account_vehicles';
  static const _walletMethodsKey = 'account_wallet_methods';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (await _storage.getTokens())['access'];
    final role = _tokenClaim(token, 'role');
    final setupDone = prefs.getBool(_setupDoneKey) ?? false;
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
          // Customer cards are loaded from the account API. Partner payout
          // details stay in their existing local flow and are Pix-only.
          .where(
            (method) =>
                role != 'customer' && method.type == WalletMethodType.pix,
          )
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

    state = AccountState(
      driverDocument: driverDocument,
      vehicles: vehicles,
      walletMethods: walletMethods,
    );
    await syncVehicles();
    await syncWalletMethods();
  }

  Future<void> syncVehicles() async {
    final token = (await _storage.getTokens())['access'];
    if (token == null || token.isEmpty) return;
    try {
      final remote = await _api.getAuthorized(
        '/customer-assets/vehicles',
        token,
      );
      if (remote.isNotEmpty) {
        state = state.copyWith(
          vehicles: remote
              .map((item) => _vehicleFromJson(item as Map<String, dynamic>))
              .toList(),
        );
        await _persistVehicles();
        return;
      }
      for (final vehicle in state.vehicles) {
        await _api.postAuthorized('/customer-assets/vehicles', {
          'nickname': vehicle.nickname,
          'plate': vehicle.plate,
          'brand': vehicle.brand,
          'model': vehicle.model,
          'color': vehicle.color,
          'vehicle_document': vehicle.documentFileName ?? 'document.pdf',
          'ownership_type': vehicle.ownershipType.name,
          'is_active': vehicle.isActive,
        }, token);
      }
    } catch (_) {
      // Offline mode keeps the local account available.
    }
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
    final token = (await _storage.getTokens())['access'];
    if (token != null && token.isNotEmpty) {
      try {
        await _api.postAuthorized('/customer-assets/vehicles', {
          'nickname': vehicle.nickname,
          'plate': vehicle.plate,
          'brand': vehicle.brand,
          'model': vehicle.model,
          'color': vehicle.color,
          'vehicle_document': vehicle.documentFileName,
          'ownership_type': vehicle.ownershipType.name,
          'is_active': vehicle.isActive,
        }, token);
      } catch (_) {
        // Keep the local cache available when the API is temporarily offline.
      }
    }
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
    if (method.type != WalletMethodType.pix) {
      final token = (await _storage.getTokens())['access'];
      if (token == null || token.isEmpty) {
        throw StateError('Entre novamente para salvar o cartão na sua conta.');
      }
      final expiry = method.expiry?.split('/') ?? const [];
      if (expiry.length != 2) {
        throw StateError('Informe a validade do cartão no formato MM/AA.');
      }
      final year = 2000 + (int.tryParse(expiry[1]) ?? 0);
      final saved = await _api
          .postAuthorized('/customer-assets/payment-methods', {
            'method_type': method.type == WalletMethodType.debitCard
                ? 'debit_card'
                : 'credit_card',
            'brand': method.brand ?? 'Cartão',
            'cardholder_name': method.holderName ?? '',
            'last_four': method.lastFour ?? '',
            'expiration_month': int.tryParse(expiry[0]) ?? 0,
            'expiration_year': year,
            'is_default': method.isActive,
          }, token);
      final savedMethod = _walletFromJson(saved);
      final updated = [
        for (final current in state.walletMethods)
          current.copyWith(
            isActive: savedMethod.isActive ? false : current.isActive,
          ),
        savedMethod,
      ];
      state = state.copyWith(walletMethods: updated);
      await _persistWalletMethods();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_walletDoneKey, state.hasActivePaymentMethod);
      return;
    }

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
    WalletMethodModel? method;
    for (final item in state.walletMethods) {
      if (item.id == methodId) {
        method = item;
        break;
      }
    }
    if (method != null && method.type != WalletMethodType.pix) {
      final token = (await _storage.getTokens())['access'];
      if (token == null || token.isEmpty) {
        throw StateError('Entre novamente para atualizar o cartão padrão.');
      }
      await _api.postAuthorized(
        '/customer-assets/payment-methods/$methodId/default',
        const {},
        token,
      );
    }
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

  Future<void> syncWalletMethods() async {
    final token = (await _storage.getTokens())['access'];
    if (token == null ||
        token.isEmpty ||
        _tokenClaim(token, 'role') != 'customer') {
      return;
    }
    try {
      final remote = await _api.getAuthorized(
        '/customer-assets/payment-methods',
        token,
      );
      state = state.copyWith(
        walletMethods: remote
            .map((item) => _walletFromJson(item as Map<String, dynamic>))
            .toList(),
      );
      await _persistWalletMethods();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_walletDoneKey, state.hasActivePaymentMethod);
    } catch (_) {
      // Account API is the source of truth for customer cards.
    }
  }

  String? _tokenClaim(String? token, String claim) {
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      return payload[claim] as String?;
    } catch (_) {
      return null;
    }
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
    final rawType = json['type'] ?? json['method_type'] ?? 'creditCard';
    return WalletMethodModel(
      id: json['id'] ?? '',
      type: WalletMethodType.values.firstWhere(
        (value) =>
            value.name == rawType ||
            (rawType == 'credit_card' &&
                value == WalletMethodType.creditCard) ||
            (rawType == 'debit_card' && value == WalletMethodType.debitCard),
        orElse: () => WalletMethodType.creditCard,
      ),
      label: json['label'] ?? 'Metodo',
      holderName: json['holderName'] ?? json['cardholder_name'],
      brand: json['brand'] ?? json['card_brand'],
      lastFour: json['lastFour'] ?? json['last_four'],
      expiry: json['expiry'],
      pixKey: json['pixKey'],
      isActive: json['isActive'] ?? false,
    );
  }
}
