import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/partner_operational_models.dart';
import '../providers/partner_operations_provider.dart';

class PartnerParkingMapPage extends ConsumerWidget {
  const PartnerParkingMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layouts = ref.watch(partnerParkingMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de vagas'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () => ref.invalidate(partnerParkingMapProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: layouts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('Nenhum estacionamento cadastrado.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            children: [
              for (final layout in items) _ParkingLayoutPanel(layout: layout),
            ],
          );
        },
      ),
    );
  }
}

class _ParkingLayoutPanel extends StatelessWidget {
  final PartnerParkingLayout layout;

  const _ParkingLayoutPanel({required this.layout});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.softCyan,
                  foregroundColor: AppTheme.primary,
                  child: Icon(Icons.local_parking),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    layout.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  label: '${layout.availableSpots} livres',
                  color: AppTheme.success,
                ),
                _StatusChip(
                  label: '${layout.preReservedSpots} pre-reservas',
                  color: Colors.orange,
                ),
                _StatusChip(
                  label: '${layout.occupiedSpots} ocupadas',
                  color: AppTheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FBFD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: layout.slots.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.sizeOf(context).width >= 900
                      ? 10
                      : 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 74,
                ),
                itemBuilder: (context, index) {
                  final slot = layout.slots[index];
                  return _ParkingSlotTile(slot: slot);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParkingSlotTile extends StatelessWidget {
  final PartnerParkingSlot slot;

  const _ParkingSlotTile({required this.slot});

  @override
  Widget build(BuildContext context) {
    final color = switch (slot.status) {
      'occupied' => AppTheme.primary,
      'pre_reserved' => Colors.orange,
      _ => AppTheme.success,
    };

    return InkWell(
      onTap: slot.reservation == null
          ? null
          : () => _showReservation(context, slot),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              slot.status == 'free'
                  ? Icons.local_parking
                  : Icons.directions_car,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              slot.code,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  void _showReservation(BuildContext context, PartnerParkingSlot slot) {
    final reservation = slot.reservation!;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.local_parking, color: AppTheme.secondary),
              const SizedBox(width: 10),
              Expanded(child: Text('Vaga ${slot.code}')),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusChip(
                        label: reservation.status,
                        color: AppTheme.primary,
                      ),
                      _StatusChip(
                        label: reservation.paymentStatus,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DetailLine(
                    'Placa',
                    reservation.vehiclePlate ?? 'Nao informada',
                  ),
                  _DetailLine(
                    'Veiculo',
                    reservation.vehicleLabel ?? 'Nao informado',
                  ),
                  _DetailLine('Vaga', reservation.spotType),
                  _DetailLine('Periodo', _periodLabel(reservation)),
                  _DetailLine(
                    'Base',
                    'R\$ ${reservation.baseAmount.toStringAsFixed(2)}',
                  ),
                  _DetailLine(
                    'Servicos',
                    'R\$ ${reservation.servicesAmount.toStringAsFixed(2)}',
                  ),
                  _DetailLine(
                    'Taxa app',
                    'R\$ ${reservation.platformFeeAmount.toStringAsFixed(2)}',
                  ),
                  _DetailLine(
                    'Total',
                    'R\$ ${reservation.finalTotal.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Servicos contratados',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (reservation.selectedServices.isEmpty)
                    const Text(
                      'Nenhum servico adicional contratado.',
                      style: TextStyle(color: AppTheme.textMuted),
                    )
                  else
                    for (final service in reservation.selectedServices)
                      _DetailLine(
                        service.name,
                        'R\$ ${service.price.toStringAsFixed(2)}',
                      ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              label: const Text('Fechar'),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Pagamento'),
            ),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.login),
              label: const Text('Check-in'),
            ),
          ],
        );
      },
    );
  }

  String _periodLabel(PartnerSlotReservation reservation) {
    final plan = switch (reservation.pricingPlan) {
      'daily' => 'diaria',
      'weekly' => 'semanal',
      'monthly' => 'mensal',
      _ => '${reservation.durationHours}h',
    };
    return plan;
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 92,
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

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}
