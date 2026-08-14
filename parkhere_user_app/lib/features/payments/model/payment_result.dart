class PaymentResult {
  final bool success;
  final String transactionId;
  final String? checkoutUrl;
  final String? qrCode;

  PaymentResult({
    required this.success,
    required this.transactionId,
    this.checkoutUrl,
    this.qrCode,
  });
}
