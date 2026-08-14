import '../model/payment_method_enum.dart';
import '../model/payment_result.dart';
import '../../../core/services/api_service.dart';

class PaymentService {
  final _api = ApiService();

  Future<PaymentResult> processPayment({
    required double amount,
    required PaymentMethod method,
    String? reservationId,
  }) async {
    if (reservationId != null) {
      final intent = await _api.post(
        "/payments/reservations/$reservationId/intent",
        {"method": _methodName(method)},
      );
      final confirmed = await _api.post(
        "/payments/${intent["id"]}/confirm",
        {},
      );

      return PaymentResult(
        success: confirmed["status"] == "paid",
        transactionId: confirmed["id"] as String,
        checkoutUrl: confirmed["checkout_url"] as String?,
        qrCode: confirmed["qr_code"] as String?,
      );
    }

    await Future.delayed(const Duration(seconds: 2));

    return PaymentResult(
      success: true,
      transactionId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  String _methodName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.pix:
        return "pix";
      case PaymentMethod.creditCard:
        return "credit_card";
      case PaymentMethod.debitCard:
        return "debit_card";
    }
  }
}
