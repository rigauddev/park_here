class PaymentResult {
  final bool success;
  final String transactionId;

  PaymentResult({
    required this.success,
    required this.transactionId,
  });
}