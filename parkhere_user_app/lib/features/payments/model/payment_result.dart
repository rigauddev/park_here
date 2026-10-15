class PaymentResult {
  final bool success;
  final bool isSimulated;
  final String transactionId;
  final String? checkoutUrl;
  final String? qrCode;
  final String method;
  final String purpose;
  final double amount;

  PaymentResult({
    required this.success,
    this.isSimulated = false,
    required this.transactionId,
    this.checkoutUrl,
    this.qrCode,
    required this.method,
    required this.purpose,
    required this.amount,
  });
}
