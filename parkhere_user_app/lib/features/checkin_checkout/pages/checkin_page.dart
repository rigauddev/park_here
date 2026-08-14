import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../reservation/models/reservation_enum.dart';
import '../../reservation/models/reservation_model.dart';
import '../../reservation/providers/reservation_provider.dart';
import '../models/pre_checkin_model.dart';
import '../../payments/pages/payment_page.dart';
import '../providers/checkout_privider.dart';

class CheckinPage extends ConsumerStatefulWidget {
  final PreCheckinModel preCheckin;
  final VoidCallback? onPaymentSuccess;

  const CheckinPage({
    super.key,
    required this.preCheckin,
    this.onPaymentSuccess,
  });

  @override
  ConsumerState<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends ConsumerState<CheckinPage> {
  bool frontPhoto = false;
  bool leftPhoto = false;
  bool rightPhoto = false;
  bool backPhoto = false;

  bool get allPhotosDone => frontPhoto && leftPhoto && rightPhoto && backPhoto;

  void _showServiceSummary(BuildContext context) {
    final pre = widget.preCheckin;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra Uber
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              Text(
                "Resumo do Check-in",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF102657),
                ),
              ),

              const SizedBox(height: 15),

              Text(
                "Estacionamento: ${pre.parking.name}",
                style: const TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 10),

              Text(
                "Plano escolhido: ${pre.plan.name.toUpperCase()}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF169FC4),
                ),
              ),

              if (pre.plan.name == "hourly")
                Text(
                  "⏱ Primeira hora: R\$ ${pre.parking.pricing.firstHourPrice}\n"
                  "➕ Hora adicional: R\$ ${pre.parking.pricing.additionalHourPrice}",
                  style: const TextStyle(fontSize: 16),
                )
              else if (pre.plan.name == "daily")
                Text(
                  "Valor: R\$ ${pre.parking.pricing.dailyPrice}",
                  style: const TextStyle(fontSize: 16),
                )
              else if (pre.plan.name == "monthly")
                Text(
                  "Valor: R\$ ${pre.parking.pricing.monthlyPrice}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              const SizedBox(height: 15),

              const Text(
                "Serviços adicionais:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              if (!pre.carWash && !pre.tourGuide && !pre.transport)
                const Text("Nenhum serviço adicional selecionado."),

              if (pre.carWash)
                _serviceItem(
                  "Lavagem pintura de veículos R\$${pre.parking.carWashPrice}",
                ),
              if (pre.tourGuide)
                _serviceItem(
                  "Guia turístico, R\$${pre.parking.tourGuidePrice}",
                ),
              if (pre.transport)
                _serviceItem("Transporte, R\$${pre.parking.transportPrice}"),

              const SizedBox(height: 15),

              const Divider(thickness: 2),

              const SizedBox(height: 15),

              if (pre.plan.name == "hourly")
                Text(
                  "Total parcial: R\$ ${pre.total}\n",
                  // "Desconto: R\$ ${pre.discount}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF169FC4),
                  ),
                ),
              if (pre.plan.name == "hourly")
                Text(
                  "O valor será calculado no checkout, de acordo com o tempo estacionado.",
                  style: const TextStyle(
                    fontSize: 13,
                    // color: Color(0xFF169FC4),
                  ),
                ),

              if (pre.plan.name != "hourly")
                Text(
                  "Total: R\$ ${pre.total}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    // color: Color(0xFF169FC4),
                  ),
                ),
              const SizedBox(height: 15),

              // Botão Confirmar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF169FC4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // fecha bottomsheet
                    _openPaymentAndConfirmCheckin();
                  },

                  child: const Text(
                    "Pagar e confirmar check-in",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _serviceItem(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parking = widget.preCheckin.parking;

    return Scaffold(
      appBar: AppBar(title: const Text("Check-in")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parking.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            const Text(
              "Tire 4 fotos obrigatórias do veículo:",
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 15),

            _photoItem("Frontal", frontPhoto, () {
              setState(() => frontPhoto = true);
            }),

            _photoItem("Lateral esquerda", leftPhoto, () {
              setState(() => leftPhoto = true);
            }),

            _photoItem("Lateral direita", rightPhoto, () {
              setState(() => rightPhoto = true);
            }),

            _photoItem("Traseira", backPhoto, () {
              setState(() => backPhoto = true);
            }),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF169FC4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: allPhotosDone
                    ? () {
                        _showServiceSummary(context);
                      }
                    : null,
                child: Text(
                  widget.preCheckin.plan.name == "hourly"
                      ? "Confirmar Check-in"
                      : "Avançar para pagamento",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoItem(String label, bool done, VoidCallback onTap) {
    return ListTile(
      leading: Icon(
        done ? Icons.check_circle : Icons.camera_alt,
        color: done ? Colors.green : Colors.grey,
      ),
      title: Text(label),
      trailing: ElevatedButton(
        onPressed: done ? null : onTap,
        child: Text(done ? "OK" : "Capturar"),
      ),
    );
  }

  void _createReservation() {
    final pre = widget.preCheckin;

    final reservation = ReservationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      parkingName: pre.parking.name,
      plan: pre.plan,
      status: ReservationStatus.open,
      checkinAt: DateTime.now(),
      estimatedValue: pre.total,
      carWash: pre.carWash,
      tourGuide: pre.tourGuide,
      transport: pre.transport,
      firstHourPrice: pre.parking.pricing.firstHourPrice,
      additionalHourPrice: pre.parking.pricing.additionalHourPrice,
      checkinTime: DateTime.now(),
      hasUnpaidServices: false,
      unpaidServicesValue: 0.0,
      validUntil: DateTime.now().add(const Duration(hours: 12)),
      preCheckin: widget.preCheckin,
    );

    ref.read(reservationsProvider.notifier).createReservation(reservation);
  }

  void _openPaymentAndConfirmCheckin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          amount: widget.preCheckin.total,
          reservationId: widget.preCheckin.reservationId,
          payNow: true,
          onPaymentSuccess: () {
            _createReservation();
            ref.read(checkoutProvider.notifier).paymentSuccess();
            if (mounted) {
              Navigator.popUntil(context, (route) => route.isFirst);
            }
          },
        ),
      ),
    );
  }
}
