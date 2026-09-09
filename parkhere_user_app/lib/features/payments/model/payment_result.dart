class PaymentResult {
  final bool success;
  final bool isSimulated;
  final String transactionId;
  final String? checkoutUrl;
  final String? qrCode;

  PaymentResult({
    required this.success,
    this.isSimulated = false,
    required this.transactionId,
    this.checkoutUrl,
    this.qrCode,
  });
}
