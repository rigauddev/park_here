import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/partner_operational_models.dart';
import '../providers/partner_operations_provider.dart';

class PartnerReservationsPage extends ConsumerWidget {
  const PartnerReservationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservations = ref.watch(partnerReservationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservas recebidas'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () => ref.invalidate(partnerReservationsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: reservations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Nenhuma reserva recebida.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _PartnerReservationCard(reservation: items[index]);
            },
          );
        },
      ),
    );
  }
}

class _PartnerReservationCard extends StatelessWidget {
  final PartnerReservationSummary reservation;

  const _PartnerReservationCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final color = switch (reservation.status) {
      'checked_in' => AppTheme.primary,
      'pre_reserved' => Colors.orange,
      'checked_out' => AppTheme.success,
      _ => AppTheme.textMuted,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  foregroundColor: color,
                  child: const Icon(Icons.confirmation_number_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reservation.customerName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        reservation.vehiclePlate ?? 'Placa nao informada',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(reservation.status),
                  backgroundColor: color.withValues(alpha: 0.1),
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Line('Estacionamento', reservation.parkingName),
            _Line('Plano', reservation.pricingPlan),
            _Line('Tipo de vaga', reservation.spotType),
            _Line('Pagamento', reservation.paymentStatus),
            _Line('Valor', 'R\$ ${reservation.finalTotal.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;

  const _Line(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
