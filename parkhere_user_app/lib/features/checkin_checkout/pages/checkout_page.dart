import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../payments/pages/payment_page.dart';
import '../../reservation/models/reservation_model.dart';
import '../../reservation/pages/incident_dailog_page.dart';
import '../providers/checkout_privider.dart';
// import '../services/checkout_service.dart';
import 'checkout_qrcode_page.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  final ReservationModel reservation;

  const CheckoutPage({super.key, required this.reservation});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  // void initState() {
  //   super.initState();

  //   /// Escuta mudanças de estado do checkout
  //   Future.microtask(() {
  //     ref.listen<CheckoutState>(
  //       checkoutProvider,
  //       (previous, next) {

  //         /// 🔹 Se precisar pagar
  //         if (next.status == CheckoutStatus.requiresPayment) {
  //           Navigator.push(
  //             context,
  //             MaterialPageRoute(
  //               builder: (_) => PaymentPage(
  //                 amount: next.amount!,
  //                 payNow: false,
  //                 onPaymentSuccess: () {
  //                   ref.read(checkoutProvider.notifier).paymentSuccess();
  //                 },
  //               ),
  //             ),
  //           );
  //         }

  //         /// 🔹 Se for gerar QR
  //         if (next.status == CheckoutStatus.generatingQr) {
  //           Navigator.pushReplacement(
  //             context,
  //             MaterialPageRoute(
  //               builder: (_) => const CheckoutQRCodePage(),
  //             ),
  //           );

  //           ref.read(checkoutProvider.notifier).complete();
  //         }

  //         /// 🔹 Se erro
  //         if (next.status == CheckoutStatus.error) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             SnackBar(content: Text(next.error ?? "Erro inesperado")),
  //           );
  //         }
  //       },
  //     );
  //   });
  // }

  /// 🔐 Popup obrigatório antes do checkout
  Future<void> _confirmVehicleCheck() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Verifique seu veículo"),
        content: const Text(
          "Antes de sair do estacionamento, verifique:\n\n"
          "• Possíveis danos\n"
          "• Objetos esquecidos\n"
          "• Portas e janelas\n\n"
          "Deseja continuar para o checkout?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Continuar"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(checkoutProvider.notifier).validate(widget.reservation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkoutProvider);

    ref.listen<CheckoutState>(checkoutProvider, (previous, next) {
      if (next.status == CheckoutStatus.requiresPayment &&
          next.amount != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentPage(
              amount: next.amount!,
              payNow: false,
              onPaymentSuccess: () {
                ref.read(checkoutProvider.notifier).paymentSuccess();
              },
            ),
          ),
        );
      }

      if (next.status == CheckoutStatus.generatingQr) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CheckoutQRCodePage()),
        );

        ref.read(checkoutProvider.notifier).complete();
      }

      if (next.status == CheckoutStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error ?? "Erro inesperado")),
        );
      }
    });
    return Scaffold(
      appBar: AppBar(title: const Text("Checkout")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 🔹 Informações da reserva
            Card(
              child: ListTile(
                title: Text("Plano: ${widget.reservation.plan.name}"),
                subtitle: Text("Check-in: ${widget.reservation.checkinTime}"),
              ),
            ),

            const SizedBox(height: 20),

            /// 🔄 Loading
            if (state.status == CheckoutStatus.validating)
              const CircularProgressIndicator(),

            const Spacer(),

            /// 🚨 Reportar incidente
            TextButton.icon(
              icon: const Icon(Icons.report_problem, color: Colors.red),
              label: const Text(
                "Reportar incidente",
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const IncidentDialog(),
                );
              },
            ),

            const SizedBox(height: 12),

            /// 🔓 Botão principal de Checkout
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.status == CheckoutStatus.validating
                    ? null
                    : _confirmVehicleCheck,
                child: const Text("Finalizar Checkout"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
