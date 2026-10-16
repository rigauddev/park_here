import '../model/payment_method_enum.dart';
import '../model/payment_result.dart';
import '../../../core/services/api_service.dart';

class PaymentService {
  final _api = ApiService();

  Future<Map<String, dynamic>> reservationQuote(
    String reservationId,
    String accessToken,
  ) {
    return _api.getAuthorizedMap(
      '/payments/reservations/$reservationId/quote',
      accessToken,
    );
  }

  Future<PaymentResult> processPayment({
    required double amount,
    required PaymentMethod method,
    required String accessToken,
    String? reservationId,
    String purpose = 'reservation',
    double? latitude,
    double? longitude,
  }) async {
    if (reservationId != null) {
      final intent = await _api.postAuthorized(
        "/payments/reservations/$reservationId/intent",
        {
          "method": _methodName(method),
          "purpose": purpose,
          if (latitude != null) "latitude": latitude,
          if (longitude != null) "longitude": longitude,
        },
        accessToken,
      );
      if (intent["is_simulated"] != true) {
        throw Exception('Pagamento aguardando confirmação do provedor.');
      }
      final confirmed = await _api.postAuthorized(
        "/payments/${intent["id"]}/confirm",
        {},
        accessToken,
      );

      return PaymentResult(
        success: confirmed["status"] == "paid",
        isSimulated: confirmed["is_simulated"] == true,
        transactionId: confirmed["id"] as String,
        checkoutUrl: confirmed["checkout_url"] as String?,
        qrCode: confirmed["qr_code"] as String?,
        method: confirmed["method"] as String? ?? _methodName(method),
        purpose: confirmed["purpose"] as String? ?? purpose,
        amount: (confirmed["gross_amount"] as num?)?.toDouble() ?? amount,
      );
    }

    throw Exception('Uma reserva é necessária para iniciar o pagamento.');
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
