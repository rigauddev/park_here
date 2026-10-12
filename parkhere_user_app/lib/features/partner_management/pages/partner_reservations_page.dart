import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/api_feedback.dart';
import '../../../core/i18n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/partner_operational_models.dart';
import '../providers/partner_operations_provider.dart';

class PartnerReservationsPage extends ConsumerStatefulWidget {
  const PartnerReservationsPage({super.key});

  @override
  ConsumerState<PartnerReservationsPage> createState() =>
      _PartnerReservationsPageState();
}

class _PartnerReservationsPageState
    extends ConsumerState<PartnerReservationsPage> {
  String parkingFilter = 'Todos';

  @override
  Widget build(BuildContext context) {
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

          final parkings = [
            'Todos',
            ...{for (final item in items) item.parkingName},
          ];
          final filtered = parkingFilter == 'Todos'
              ? items
              : items
                    .where((item) => item.parkingName == parkingFilter)
                    .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: parkings.contains(parkingFilter)
                    ? parkingFilter
                    : 'Todos',
                decoration: const InputDecoration(
                  labelText: 'Filtrar por estacionamento',
                ),
                items: [
                  for (final item in parkings)
                    DropdownMenuItem(
                      value: item,
                      child: Text(item, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => parkingFilter = value ?? 'Todos'),
              ),
              const SizedBox(height: 12),
              for (final item in filtered)
                _PartnerReservationCard(reservation: item),
            ],
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
                      label: Text(
                        context.strings.reservationStatus(reservation.status),
                      ),
                      backgroundColor: color.withValues(alpha: 0.1),
                      side: BorderSide.none,
                    ),
                    Chip(
                      label: Text(
                        context.strings.paymentStatus(
                          reservation.paymentStatus,
                        ),
                      ),
                      backgroundColor: AppTheme.softCyan,
                      side: BorderSide.none,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Line('Estacionamento', reservation.parkingName),
            _Line('Reserva', _displayReservationNumber(reservation.id)),
            if (reservation.createdByName != null)
              _Line('Criada por', reservation.createdByName!),
            if (reservation.customerPhone != null)
              _Line('Telefone', reservation.customerPhone!),
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
            if (reservation.customerPhone != null &&
                reservation.customerName != 'Cliente nao informado')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _shareApp(reservation),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Compartilhar app'),
                ),
              ),
            if (reservation.cancelledByName != null)
              _Line('Cancelada por', reservation.cancelledByName!),
            if (reservation.status == 'checked_in' &&
                reservation.checkoutExcessMinutes > 0) ...[
              _Line(
                'Tempo excedido',
                '${reservation.checkoutExcessMinutes} min',
              ),
              _Line(
                'Excedente no checkout',
                'R\$ ${reservation.checkoutExcessAmount.toStringAsFixed(2)}',
              ),
            ],
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
            if (reservation.status == 'pending_operator_approval') ...[
              const SizedBox(height: 12),
              Text(
                'Entrada fora do horário: confirme se o estacionamento aceitará esta chegada.',
                style: TextStyle(color: Colors.orange.shade800),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                FilledButton.icon(
                  onPressed: () => _reviewArrival(context, ref, 'approve'),
                  icon: const Icon(Icons.check),
                  label: const Text('Aceitar entrada'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _reviewArrival(context, ref, 'reject'),
                  icon: const Icon(Icons.close),
                  label: const Text('Recusar'),
                ),
              ]),
            ],
            if (reservation.status != 'completed' &&
                reservation.status != 'cancelled' &&
                reservation.status != 'checked_in' &&
                reservation.status != 'confirmed') ...[
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

  Future<void> _reviewArrival(
    BuildContext context,
    WidgetRef ref,
    String decision,
  ) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    try {
      await reviewArrivalApproval(
        token: token,
        reservationId: reservation.id,
        decision: decision,
      );
      ref.invalidate(partnerReservationsProvider);
      ref.invalidate(partnerParkingMapProvider);
      if (context.mounted) {
        await ApiFeedback.show(
          context,
          decision == 'approve'
              ? 'Entrada aceita e reserva confirmada.'
              : 'Solicitação recusada e vaga liberada.',
          isError: false,
        );
      }
    } catch (error) {
      if (context.mounted) await ApiFeedback.show(context, '$error');
    }
  }

  Future<void> _shareApp(PartnerReservationSummary item) async {
    final phone = (item.customerPhone ?? '').replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) return;
    final message = Uri.encodeComponent(
      'Olá ${item.customerName}, cadastre-se e acompanhe sua reserva, realize o pagamento e agilize seu checkout no app ParkHere: https://parkhere.app/download',
    );
    final uri = Uri.parse('https://wa.me/$phone?text=$message');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

String _displayReservationNumber(String id) {
  final compact = id.replaceAll('-', '').toUpperCase();
  return 'PH-${compact.substring(0, compact.length.clamp(0, 8))}';
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
      await ApiFeedback.show(context, 'Reserva cancelada.', isError: false);
    } catch (error) {
      if (!mounted) return;
      await ApiFeedback.show(context, 'Erro ao cancelar reserva: $error');
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
