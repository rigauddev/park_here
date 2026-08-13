import '../model/payment_method_enum.dart';
import '../model/payment_result.dart';

class PaymentService {
  static Future<PaymentResult> processPayment({
    required double amount,
    required PaymentMethod method,
  }) async {
    // 🔥 Simula chamada backend
    await Future.delayed(const Duration(seconds: 2));

    // Aqui no futuro você troca por API real

    return PaymentResult(
      success: true,
      transactionId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }
}
