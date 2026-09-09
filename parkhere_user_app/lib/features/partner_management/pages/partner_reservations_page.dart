import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
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

class _PartnerReservationCard extends ConsumerWidget {
  final PartnerReservationSummary reservation;

  const _PartnerReservationCard({required this.reservation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = switch (reservation.status) {
      'checked_in' => AppTheme.primary,
      'pre_reserved' => Colors.orange,
      'completed' => AppTheme.success,
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
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    Chip(
                      label: Text(_statusLabel(reservation.status)),
                      backgroundColor: color.withValues(alpha: 0.1),
                      side: BorderSide.none,
                    ),
                    Chip(
                      label: Text(_paymentLabel(reservation.paymentStatus)),
                      backgroundColor: AppTheme.softCyan,
                      side: BorderSide.none,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Line('Estacionamento', reservation.parkingName),
            _Line('Plano', _planLabel(reservation.pricingPlan)),
            _Line('Tipo de vaga', _spotTypeLabel(reservation.spotType)),
            _Line('Base', 'R\$ ${reservation.baseAmount.toStringAsFixed(2)}'),
            _Line(
              'Servicos',
              'R\$ ${reservation.servicesAmount.toStringAsFixed(2)}',
            ),
            _Line(
              'Taxa app',
              'R\$ ${reservation.platformFeeAmount.toStringAsFixed(2)}',
            ),
            _Line('Total', 'R\$ ${reservation.finalTotal.toStringAsFixed(2)}'),
            if (reservation.selectedServices.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Servicos contratados',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final service in reservation.selectedServices)
                    Chip(
                      label: Text(
                        '${service.name} · R\$ ${service.price.toStringAsFixed(2)}',
                      ),
                      backgroundColor: const Color(0xFFF7FBFD),
                      side: const BorderSide(color: Color(0xFFD9E8F0)),
                    ),
                ],
              ),
            ],
            if (reservation.status != 'completed' &&
                reservation.status != 'cancelled') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _openCancelDialog(context, ref),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openCancelDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _ReservationCancelDialog(
        reservationId: reservation.id,
        checkedIn: reservation.status == 'checked_in',
        onCompleted: () {
          ref.invalidate(partnerReservationsProvider);
          ref.invalidate(partnerParkingMapProvider);
        },
      ),
    );
  }

  String _statusLabel(String value) {
    return switch (value) {
      'pre_reserved' => 'Pre-reserva',
      'confirmed' => 'Confirmada',
      'checked_in' => 'Em permanencia',
      'completed' => 'Finalizada',
      _ => value,
    };
  }

  String _paymentLabel(String value) {
    return switch (value) {
      'pending_checkin' => 'Pagamento no checkout',
      'payment_pending' => 'Pagamento pendente',
      'paid' => 'Pago',
      _ => value,
    };
  }

  String _planLabel(String value) {
    return switch (value) {
      'hourly' => 'Por hora',
      'daily' => 'Diaria',
      'weekly' => 'Semanal',
      'monthly' => 'Mensal',
      _ => value,
    };
  }

  String _spotTypeLabel(String value) {
    return switch (value) {
      'covered' => 'Coberta',
      'uncovered' => 'Descoberta',
      'vip' => 'VIP',
      'large' => 'Carro grande',
      'bus' => 'Onibus',
      'pickup' => 'Picape',
      _ => value,
    };
  }
}

class _ReservationCancelDialog extends ConsumerStatefulWidget {
  final String reservationId;
  final bool checkedIn;
  final VoidCallback onCompleted;

  const _ReservationCancelDialog({
    required this.reservationId,
    required this.checkedIn,
    required this.onCompleted,
  });

  @override
  ConsumerState<_ReservationCancelDialog> createState() =>
      _ReservationCancelDialogState();
}

class _ReservationCancelDialogState
    extends ConsumerState<_ReservationCancelDialog> {
  final reasonController = TextEditingController();
  bool isSubmitting = false;

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancelar reserva'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.checkedIn
                ? 'Reserva com check-in so pode ser cancelada pelo gestor do parceiro.'
                : 'Cancelamento em ate 5 minutos nao gera custo. Depois, aplica taxa administrativa configurada pelo gestor do app.',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reasonController,
            enabled: !isSubmitting,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motivo do cancelamento',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Voltar'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: isSubmitting ? null : _cancel,
          icon: isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cancel_outlined),
          label: const Text('Confirmar cancelamento'),
        ),
      ],
    );
  }

  Future<void> _cancel() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;

    setState(() => isSubmitting = true);
    try {
      await cancelOperationalReservation(
        token: token,
        reservationId: widget.reservationId,
        reason: reasonController.text.trim(),
      );
      widget.onCompleted();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reserva cancelada.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cancelar reserva: $error')),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
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
