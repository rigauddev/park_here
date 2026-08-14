enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  mfaRequired,
}

enum AuthAccountType { customer, partner }

class AuthState {
  final AuthStatus status;
  final String? accessToken;
  final String? refreshToken;
  final String? userEmail;
  final AuthAccountType? accountType;
  final String? mfaToken;

  const AuthState({
    required this.status,
    this.accessToken,
    this.refreshToken,
    this.userEmail,
    this.accountType,
    this.mfaToken,
  });

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);

  AuthState copyWith({
    AuthStatus? status,
    String? accessToken,
    String? refreshToken,
    String? userEmail,
    AuthAccountType? accountType,
    String? mfaToken,
    bool clearMfaToken = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      userEmail: userEmail ?? this.userEmail,
      accountType: accountType ?? this.accountType,
      mfaToken: clearMfaToken ? null : mfaToken ?? this.mfaToken,
    );
  }
}
