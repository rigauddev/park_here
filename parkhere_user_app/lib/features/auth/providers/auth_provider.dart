import 'package:flutter_riverpod/legacy.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../models/auth_state.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.initial()) {
    checkAuthOnStartup();
  }

  final _storage = LocalStorageService();
  final _api = ApiService();

  /// 🔎 Verifica token ao iniciar app
  Future<void> checkAuthOnStartup() async {
    final tokens = await _storage.getTokens();
    final accountType = tokens["account_type"] == "partner"
        ? AuthAccountType.partner
        : AuthAccountType.customer;

    if (tokens["access"] != null) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        accessToken: tokens["access"],
        refreshToken: tokens["refresh"],
        userEmail: tokens["user_email"],
        accountType: accountType,
        clearMfaToken: true,
      );
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// 🔑 LOGIN
  Future<void> login(
    String email,
    String password, {
    AuthAccountType accountType = AuthAccountType.customer,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    final normalizedEmail = email.toLowerCase();
    final accountTypeName = accountType == AuthAccountType.customer
        ? "customer"
        : "partner";

    try {
      final response = await _api.post("/auth/login", {
        "email": normalizedEmail,
        "password": password,
        "account_type": accountTypeName,
      });

      state = state.copyWith(
        status: AuthStatus.mfaRequired,
        userEmail: normalizedEmail,
        accountType: accountType,
        mfaToken: response["mfa_token"] as String?,
      );
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      throw Exception("Credenciais inválidas");
    }
  }

  /// 🔐 MFA
  Future<void> verifyMfa(String code) async {
    final mfaToken = state.mfaToken;

    if (mfaToken == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      throw Exception("Credenciais inválidas");
    }

    try {
      final response = await _api.post("/auth/verify-mfa", {
        "mfa_token": mfaToken,
        "code": code,
      });

      final accessToken = response["access_token"] as String;
      final refreshToken = response["refresh_token"] as String;
      final accountType = state.accountType ?? AuthAccountType.customer;
      final accountTypeName = accountType == AuthAccountType.customer
          ? "customer"
          : "partner";

      await _storage.saveTokens(
        accessToken,
        refreshToken,
        accountType: accountTypeName,
        userEmail: state.userEmail,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        accessToken: accessToken,
        refreshToken: refreshToken,
        accountType: accountType,
        clearMfaToken: true,
      );
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      throw Exception("Credenciais inválidas");
    }
  }

  Future<String> requestEmailValidationCode(String email) async {
    final response = await _api.post("/auth/email/request-code", {
      "email": email.trim().toLowerCase(),
    });
    return response["email_token"] as String;
  }

  Future<void> verifyEmailValidationCode(String token, String code) async {
    await _api.post("/auth/email/verify-code", {
      "email_token": token,
      "code": code,
    });
  }

  Future<String> requestPasswordReset(String email) async {
    final response = await _api.post("/auth/password/request-reset", {
      "email": email.trim().toLowerCase(),
    });
    return response["reset_token"] as String;
  }

  Future<void> verifyPasswordResetCode(String token, String code) async {
    await _api.post("/auth/password/verify-code", {
      "reset_token": token,
      "code": code,
    });
  }

  Future<void> resetPassword({
    required String token,
    required String code,
    required String newPassword,
  }) async {
    await _api.post("/auth/password/reset", {
      "reset_token": token,
      "code": code,
      "new_password": newPassword,
    });
  }

  /// 🆕 REGISTER
  Future<void> register(String name, String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);

    await Future.delayed(const Duration(seconds: 1));

    // Aqui depois vai chamar backend

    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  /// 🔄 REFRESH TOKEN
  Future<void> refreshToken() async {
    final tokens = await _storage.getTokens();

    if (tokens["refresh"] == null) {
      logout();
      return;
    }

    // Aqui depois chamará backend
    const newAccess = "new_access_token";

    await _storage.saveTokens(
      newAccess,
      tokens["refresh"]!,
      accountType: tokens["account_type"],
      userEmail: tokens["user_email"],
    );

    state = state.copyWith(accessToken: newAccess);
  }

  /// 🚪 LOGOUT
  Future<void> logout() async {
    await _storage.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
