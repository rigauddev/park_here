class CheckoutToken {
  final String token;
  final DateTime expiresAt;

  CheckoutToken({required this.token, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
