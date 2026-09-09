import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../checkin_checkout/pages/checkout_page.dart';
import '../../payments/pages/payment_page.dart';
import '../models/reservation_enum.dart';
import '../models/reservation_model.dart';
import '../providers/reservation_provider.dart';

class ReservationDetailsPage extends ConsumerStatefulWidget {
  final ReservationModel reservation;

  const ReservationDetailsPage({super.key, required this.reservation});

  @override
  ConsumerState<ReservationDetailsPage> createState() =>
      _ReservationDetailsPageState();
}

class _ReservationDetailsPageState
    extends ConsumerState<ReservationDetailsPage> {
  late int parkingRating = widget.reservation.parkingRating ?? 0;
  late int appRating = widget.reservation.appRating ?? 0;
  final commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    commentController.text = widget.reservation.ratingComment ?? '';
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reservation = widget.reservation;

    return Scaffold(
      appBar: AppBar(title: const Text("Detalhes da reserva")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            reservation.parkingName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            "Reserva #${reservation.id}",
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 18),
          _Section(
            title: "Resumo",
            children: [
              _DetailRow("Status", _statusLabel(reservation.status)),
              _DetailRow("Plano", reservation.plan.name.toUpperCase()),
              _DetailRow("Check-in", _formatDate(reservation.checkinAt)),
              if (reservation.checkoutAt != null)
                _DetailRow("Check-out", _formatDate(reservation.checkoutAt!)),
              _DetailRow("Validade", _formatDate(reservation.validUntil)),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: "Valores",
            children: [
              _DetailRow(
                "Estimado",
                "R\$ ${reservation.estimatedValue.toStringAsFixed(2)}",
              ),
              if (reservation.finalValue != null)
                _DetailRow(
                  "Final",
                  "R\$ ${reservation.finalValue!.toStringAsFixed(2)}",
                ),
              _DetailRow(
                "Primeira hora",
                "R\$ ${reservation.firstHourPrice.toStringAsFixed(2)}",
              ),
              _DetailRow(
                "Hora adicional",
                "R\$ ${reservation.additionalHourPrice.toStringAsFixed(2)}",
              ),
              _DetailRow(
                "Taxa administrativa do app",
                "R\$ ${reservation.preCheckin.platformFeeAmount.toStringAsFixed(2)}",
              ),
            ],
          ),
          if (reservation.status == ReservationStatus.open &&
              reservation.id.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Garantir reserva antecipadamente'),
                  subtitle: Text(
                    'Pague agora R\$ ${reservation.estimatedValue.toStringAsFixed(2)}',
                  ),
                  trailing: FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentPage(
                          amount: reservation.estimatedValue,
                          reservationId: reservation.id,
                          payNow: true,
                          onPaymentSuccess: () {},
                        ),
                      ),
                    ),
                    child: const Text('Pagar'),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          _Section(
            title: "Servicos adicionais",
            children: [
              _DetailRow("Lava-jato", reservation.carWash ? "Sim" : "Nao"),
              _DetailRow(
                "Guia turistico",
                reservation.tourGuide ? "Sim" : "Nao",
              ),
              _DetailRow("Transporte", reservation.transport ? "Sim" : "Nao"),
              _DetailRow(
                "Servicos pendentes",
                reservation.hasUnpaidServices
                    ? "R\$ ${reservation.unpaidServicesValue.toStringAsFixed(2)}"
                    : "Nao",
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: "Avaliacao",
            children: [
              const Text("Nota para o estacionamento"),
              const SizedBox(height: 4),
              _StarRating(
                value: parkingRating,
                onChanged: (value) => setState(() => parkingRating = value),
              ),
              const SizedBox(height: 12),
              const Text("Nota para o app"),
              const SizedBox(height: 4),
              _StarRating(
                value: appRating,
                onChanged: (value) => setState(() => appRating = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Comentario opcional",
                  prefixIcon: Icon(Icons.rate_review_outlined),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saveRating,
                icon: const Icon(Icons.star),
                label: const Text("Salvar avaliacao"),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar:
          reservation.status == ReservationStatus.open && reservation.checkedIn
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CheckoutPage(reservation: reservation),
                    ),
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text("Fazer checkout"),
              ),
            )
          : null,
    );
  }

  Future<void> _saveRating() async {
    if (parkingRating == 0 || appRating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Informe as duas notas.")));
      return;
    }

    await ref
        .read(reservationsProvider.notifier)
        .rateReservation(
          id: widget.reservation.id,
          parkingRating: parkingRating,
          appRating: appRating,
          comment: commentController.text.trim().isEmpty
              ? null
              : commentController.text.trim(),
        );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Avaliacao salva.")));
  }

  String _statusLabel(ReservationStatus status) {
    switch (status) {
      case ReservationStatus.open:
        return "Aberta";
      case ReservationStatus.finished:
        return "Finalizada";
      case ReservationStatus.expired:
        return "Expirada";
      case ReservationStatus.cancelled:
        return "Cancelada";
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return "$day/$month/${date.year} $hour:$minute";
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _StarRating({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 1; index <= 5; index++)
          IconButton(
            onPressed: () => onChanged(index),
            icon: Icon(index <= value ? Icons.star : Icons.star_border),
            color: index <= value ? Colors.amber.shade700 : AppTheme.textMuted,
            tooltip: "$index estrelas",
          ),
      ],
    );
  }
}
