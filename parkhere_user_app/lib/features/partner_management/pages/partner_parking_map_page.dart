import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
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
              for (final layout in items)
                _ParkingLayoutPanel(layout: layout, showFinancialSummary: true),
            ],
          );
        },
      ),
    );
  }
}

class _ParkingLayoutPanel extends StatelessWidget {
  final PartnerParkingLayout layout;
  final bool showFinancialSummary;

  const _ParkingLayoutPanel({
    required this.layout,
    required this.showFinancialSummary,
  });

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
            if (showFinancialSummary) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MoneySummaryCard(
                    icon: Icons.schedule,
                    label: 'Pre-reservas',
                    value: layout.preReservedAmount,
                    count: layout.preReservedSpots,
                    color: Colors.orange,
                    tooltip:
                        'Soma das pre-reservas aguardando confirmacao ou chegada.',
                  ),
                  _MoneySummaryCard(
                    icon: Icons.verified_outlined,
                    label: 'Reservas confirmadas',
                    value: layout.confirmedAmount,
                    color: AppTheme.success,
                    tooltip:
                        'Soma das reservas confirmadas, com vaga bloqueada.',
                  ),
                  _MoneySummaryCard(
                    icon: Icons.login,
                    label: 'Em permanencia',
                    value: layout.checkedInAmount,
                    count: layout.occupiedSpots,
                    color: AppTheme.primary,
                    tooltip:
                        'Valores de reservas com check-in realizado e veiculo no patio.',
                  ),
                  _MoneySummaryCard(
                    icon: Icons.point_of_sale,
                    label: 'Recebido no caixa',
                    value: layout.paidAmount,
                    color: const Color(0xFF00897B),
                    tooltip:
                        'Total ja registrado como pago para este estabelecimento.',
                  ),
                  _MoneySummaryCard(
                    icon: Icons.pending_actions,
                    label: 'A receber',
                    value: layout.pendingPaymentAmount,
                    color: Colors.red,
                    tooltip:
                        'Total pendente de pagamento no check-in ou checkout.',
                  ),
                  _MoneySummaryCard(
                    icon: Icons.cancel_outlined,
                    label: 'Canceladas',
                    value: layout.cancelledAmount,
                    count: layout.cancelledSpots,
                    color: Theme.of(context).colorScheme.error,
                    tooltip:
                        'Quantidade e valor bruto das reservas canceladas neste estacionamento.',
                  ),
                  _MoneySummaryCard(
                    icon: Icons.local_car_wash,
                    label: 'Servicos pre-reserva',
                    value: layout.servicesAmountByStatus['pre_reserved'] ?? 0,
                    color: Colors.orange,
                    tooltip: 'Soma dos servicos adicionais em pre-reservas.',
                  ),
                  _MoneySummaryCard(
                    icon: Icons.miscellaneous_services,
                    label: 'Servicos confirmados',
                    value: layout.servicesAmountByStatus['confirmed'] ?? 0,
                    color: AppTheme.success,
                    tooltip:
                        'Soma dos servicos adicionais em reservas confirmadas.',
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
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
                  mainAxisExtent: 96,
                ),
                itemBuilder: (context, index) {
                  final slot = layout.slots[index];
                  return _ParkingSlotTile(parkingId: layout.id, slot: slot);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParkingSlotTile extends ConsumerWidget {
  final String parkingId;
  final PartnerParkingSlot slot;

  const _ParkingSlotTile({required this.parkingId, required this.slot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = switch (slot.status) {
      'occupied' => AppTheme.primary,
      'pre_reserved' => Colors.orange,
      _ => AppTheme.success,
    };
    final slotTypeLabel = _slotTypeLabel(slot.type);

    return InkWell(
      onTap: slot.reservation == null
          ? () => _showCreateReservation(context, parkingId, slot)
          : () => _showReservation(context, ref, slot),
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
            Text(
              slotTypeLabel,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (slot.reservation != null &&
                slot.reservation!.status != 'checked_in') ...[
              const SizedBox(height: 2),
              Text(
                _arrivalPreview(slot.reservation!),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _arrivalPreview(PartnerSlotReservation reservation) {
    final arrival = reservation.arrivalEstimateAt.toLocal();
    final hour = arrival.hour.toString().padLeft(2, '0');
    final minute = arrival.minute.toString().padLeft(2, '0');
    if (reservation.isManualArrival) return 'Chega ${hour}h$minute';
    return '${reservation.routeMinutes} min · ${hour}h$minute';
  }

  void _showCreateReservation(
    BuildContext context,
    String parkingId,
    PartnerParkingSlot slot,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _FreeSlotReservationDialog(
        parkingId: parkingId,
        slotCode: slot.code,
        slotType: slot.type,
      ),
    );
  }

  void _showReservation(
    BuildContext context,
    WidgetRef ref,
    PartnerParkingSlot slot,
  ) {
    final reservation = slot.reservation!;
    final canCheckin =
        reservation.status == 'pre_reserved' ||
        reservation.status == 'confirmed';
    final canCheckout =
        reservation.status == 'checked_in' &&
        reservation.paymentStatus == 'paid';
    final auth = ref.read(authProvider);
    final canCancel =
        reservation.status != 'checked_in' ||
        auth.role == 'partner_manager' ||
        auth.role == 'parking_admin';
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
                  _DetailLine('Previsao chegada', _arrivalDetail(reservation)),
                  _DetailLine(
                    'Vaga',
                    '${slot.code} · ${_slotTypeLabel(slot.type)}',
                  ),
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
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: canCancel
                  ? () {
                      Navigator.pop(context);
                      showDialog<void>(
                        context: context,
                        builder: (_) => _CancelReservationDialog(
                          reservationId: reservation.id,
                          checkedIn: reservation.status == 'checked_in',
                          onCompleted: () {
                            ref.invalidate(partnerParkingMapProvider);
                            ref.invalidate(partnerReservationsProvider);
                          },
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar'),
            ),
            OutlinedButton.icon(
              onPressed: reservation.paymentStatus == 'paid'
                  ? null
                  : () {
                      Navigator.pop(context);
                      showDialog<void>(
                        context: context,
                        builder: (_) => _CashierPaymentDialog(
                          reservationId: reservation.id,
                          amount: reservation.finalTotal,
                          onCompleted: () {
                            ref.invalidate(partnerParkingMapProvider);
                            ref.invalidate(partnerReservationsProvider);
                          },
                        ),
                      );
                    },
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Pagamento'),
            ),
            FilledButton.icon(
              onPressed: canCheckin
                  ? () {
                      Navigator.pop(context);
                      showDialog<void>(
                        context: context,
                        builder: (_) => _CheckinPhotosDialog(
                          reservationId: reservation.id,
                          onCompleted: () {
                            ref.invalidate(partnerParkingMapProvider);
                            ref.invalidate(partnerReservationsProvider);
                          },
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.login),
              label: const Text('Check-in'),
            ),
            FilledButton.icon(
              onPressed: canCheckout
                  ? () {
                      Navigator.pop(context);
                      showDialog<void>(
                        context: context,
                        builder: (_) => _CheckoutPhotosDialog(
                          reservationId: reservation.id,
                          onCompleted: () {
                            ref.invalidate(partnerParkingMapProvider);
                            ref.invalidate(partnerReservationsProvider);
                          },
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.logout),
              label: const Text('Checkout'),
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

  String _arrivalDetail(PartnerSlotReservation reservation) {
    final arrival = reservation.arrivalEstimateAt.toLocal();
    final hour = arrival.hour.toString().padLeft(2, '0');
    final minute = arrival.minute.toString().padLeft(2, '0');
    if (reservation.isManualArrival) {
      return 'Informada manualmente · ${hour}h$minute';
    }
    return '${reservation.routeMinutes} minutos · ${hour}h$minute';
  }

  String _slotTypeLabel(String type) {
    return switch (type) {
      'covered' => 'Coberta',
      'vip' => 'VIP',
      'large' => 'Carro grande',
      'bus' => 'Onibus',
      'pickup' => 'Picape',
      _ => 'Descoberta',
    };
  }
}

class _FreeSlotReservationDialog extends ConsumerStatefulWidget {
  final String parkingId;
  final String slotCode;
  final String slotType;

  const _FreeSlotReservationDialog({
    required this.parkingId,
    required this.slotCode,
    required this.slotType,
  });

  @override
  ConsumerState<_FreeSlotReservationDialog> createState() =>
      _FreeSlotReservationDialogState();
}

class _FreeSlotReservationDialogState
    extends ConsumerState<_FreeSlotReservationDialog> {
  final cashReceivedController = TextEditingController();
  final arrivalTimeController = TextEditingController();
  _OperationalReservationMode mode = _OperationalReservationMode.preReserve;
  _OperationalPaymentMethod paymentMethod = _OperationalPaymentMethod.cash;
  _OperationalPricingPlan pricingPlan = _OperationalPricingPlan.hourly;
  _OperationalPayTiming payTiming = _OperationalPayTiming.checkout;
  TimeOfDay arrivalTime = TimeOfDay.now();
  String? pixQrCode;
  String? pendingPixPaymentId;
  double? finalTotal;
  double? changeAmount;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    arrivalTime = now;
    arrivalTimeController.text = _formatTime(now);
  }

  @override
  void dispose() {
    cashReceivedController.dispose();
    arrivalTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Vaga ${widget.slotCode}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Crie uma pre-reserva sem pagamento ou uma reserva confirmada com pagamento.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 10),
              _DetailLine('Tipo de vaga', _slotTypeLabel(widget.slotType)),
              TextField(
                controller: arrivalTimeController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Previsao manual de chegada',
                  prefixIcon: Icon(Icons.schedule),
                ),
                onTap: isSubmitting
                    ? null
                    : () async {
                        final selected = await showTimePicker(
                          context: context,
                          initialTime: arrivalTime,
                        );
                        if (selected == null) return;
                        setState(() {
                          arrivalTime = selected;
                          arrivalTimeController.text = _formatTime(selected);
                        });
                      },
              ),
              const SizedBox(height: 14),
              SegmentedButton<_OperationalReservationMode>(
                segments: const [
                  ButtonSegment(
                    value: _OperationalReservationMode.preReserve,
                    icon: Icon(Icons.schedule),
                    label: Text('Pre-reserva'),
                  ),
                  ButtonSegment(
                    value: _OperationalReservationMode.paidReservation,
                    icon: Icon(Icons.verified_outlined),
                    label: Text('Reserva'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: isSubmitting
                    ? null
                    : (values) => setState(() {
                        mode = values.first;
                        if (pricingPlan == _OperationalPricingPlan.hourly) {
                          payTiming = _OperationalPayTiming.checkout;
                        }
                        pixQrCode = null;
                        pendingPixPaymentId = null;
                        finalTotal = null;
                        changeAmount = null;
                      }),
              ),
              if (mode == _OperationalReservationMode.paidReservation) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<_OperationalPricingPlan>(
                  initialValue: pricingPlan,
                  decoration: const InputDecoration(labelText: 'Modalidade'),
                  items: const [
                    DropdownMenuItem(
                      value: _OperationalPricingPlan.hourly,
                      child: Text('Por hora'),
                    ),
                    DropdownMenuItem(
                      value: _OperationalPricingPlan.daily,
                      child: Text('Diaria'),
                    ),
                    DropdownMenuItem(
                      value: _OperationalPricingPlan.weekly,
                      child: Text('Semanal'),
                    ),
                    DropdownMenuItem(
                      value: _OperationalPricingPlan.monthly,
                      child: Text('Mensal'),
                    ),
                  ],
                  onChanged: isSubmitting
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            pricingPlan = value;
                            if (pricingPlan == _OperationalPricingPlan.hourly) {
                              payTiming = _OperationalPayTiming.checkout;
                            }
                            pixQrCode = null;
                            pendingPixPaymentId = null;
                            finalTotal = null;
                            changeAmount = null;
                          });
                        },
                ),
                const SizedBox(height: 12),
                SegmentedButton<_OperationalPayTiming>(
                  segments: const [
                    ButtonSegment(
                      value: _OperationalPayTiming.now,
                      icon: Icon(Icons.payments_outlined),
                      label: Text('Pagar agora'),
                    ),
                    ButtonSegment(
                      value: _OperationalPayTiming.checkout,
                      icon: Icon(Icons.logout),
                      label: Text('Na volta'),
                    ),
                  ],
                  selected: {payTiming},
                  onSelectionChanged:
                      isSubmitting ||
                          pricingPlan == _OperationalPricingPlan.hourly
                      ? null
                      : (values) => setState(() {
                          payTiming = values.first;
                          pixQrCode = null;
                          pendingPixPaymentId = null;
                          finalTotal = null;
                          changeAmount = null;
                        }),
                ),
                if (pricingPlan == _OperationalPricingPlan.hourly)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Na modalidade por hora, o pagamento deve ser realizado no checkout.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
              ],
              if (mode == _OperationalReservationMode.paidReservation &&
                  payTiming == _OperationalPayTiming.now) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<_OperationalPaymentMethod>(
                  initialValue: paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Forma de pagamento',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: _OperationalPaymentMethod.cash,
                      child: Text('Dinheiro'),
                    ),
                    DropdownMenuItem(
                      value: _OperationalPaymentMethod.pix,
                      child: Text('Pix'),
                    ),
                    DropdownMenuItem(
                      value: _OperationalPaymentMethod.card,
                      child: Text('Cartao - maquininha V2'),
                    ),
                  ],
                  onChanged: isSubmitting
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            paymentMethod = value;
                            pixQrCode = null;
                            pendingPixPaymentId = null;
                            finalTotal = null;
                            changeAmount = null;
                          });
                        },
                ),
                if (paymentMethod == _OperationalPaymentMethod.cash) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: cashReceivedController,
                    enabled: !isSubmitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor recebido',
                      prefixText: 'R\$ ',
                    ),
                  ),
                ],
                if (paymentMethod == _OperationalPaymentMethod.card) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Integracao com maquininha sera habilitada na V2.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ],
                if (finalTotal != null) ...[
                  const SizedBox(height: 12),
                  _DetailLine('Total', 'R\$ ${finalTotal!.toStringAsFixed(2)}'),
                ],
                if (changeAmount != null)
                  _DetailLine(
                    'Troco',
                    'R\$ ${changeAmount!.toStringAsFixed(2)}',
                  ),
                if (pixQrCode != null) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: QrImageView(
                      data: pixQrCode!,
                      size: 180,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    pixQrCode!,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
              if (mode == _OperationalReservationMode.paidReservation) ...[
                const SizedBox(height: 10),
                Text(
                  payTiming == _OperationalPayTiming.now
                      ? 'O pagamento fica registrado para cliente, estabelecimento e admin do sistema.'
                      : 'A reserva fica pendente no caixa para receber no checkout.',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed:
              !isSubmitting &&
                  (payTiming == _OperationalPayTiming.checkout ||
                      paymentMethod != _OperationalPaymentMethod.card)
              ? _submit
              : null,
          icon: isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(
            pendingPixPaymentId != null
                ? 'Confirmar Pix pago'
                : mode == _OperationalReservationMode.preReserve
                ? 'Criar pre-reserva'
                : 'Criar reserva',
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;

    setState(() => isSubmitting = true);
    try {
      if (pendingPixPaymentId != null) {
        await confirmOperationalPayment(
          token: token,
          paymentId: pendingPixPaymentId!,
        );
        ref.invalidate(partnerParkingMapProvider);
        ref.invalidate(partnerReservationsProvider);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pix confirmado e reserva paga.')),
        );
        return;
      }

      final reservation = await createOperationalReservation(
        token: token,
        parkingId: widget.parkingId,
        spotCode: widget.slotCode,
        spotType: widget.slotType,
        pricingPlan: mode == _OperationalReservationMode.paidReservation
            ? pricingPlan.apiValue
            : _OperationalPricingPlan.hourly.apiValue,
        durationHours: 1,
        arrivalEstimateAt: _arrivalDateTime(),
      );
      final reservationId = reservation['id'] as String;

      if (mode == _OperationalReservationMode.paidReservation &&
          payTiming == _OperationalPayTiming.now) {
        final payment = await createOperationalPaymentIntent(
          token: token,
          reservationId: reservationId,
          method: paymentMethod.apiValue,
        );
        final total = (payment['gross_amount'] as num).toDouble();

        if (paymentMethod == _OperationalPaymentMethod.cash) {
          final received = _parseMoney(cashReceivedController.text);
          if (received < total) {
            throw Exception('Valor recebido menor que o total.');
          }
          await confirmOperationalPayment(
            token: token,
            paymentId: payment['id'] as String,
          );
          setState(() {
            finalTotal = total;
            changeAmount = received - total;
          });
        } else if (paymentMethod == _OperationalPaymentMethod.pix) {
          setState(() {
            finalTotal = total;
            pixQrCode = payment['qr_code'] as String?;
            pendingPixPaymentId = payment['id'] as String;
          });
          return;
        }
      }

      ref.invalidate(partnerParkingMapProvider);
      ref.invalidate(partnerReservationsProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mode == _OperationalReservationMode.preReserve
                ? 'Pre-reserva criada.'
                : payTiming == _OperationalPayTiming.now
                ? 'Reserva confirmada com pagamento.'
                : 'Reserva criada para pagamento no checkout.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao criar reserva: $error')));
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  double _parseMoney(String value) {
    final normalized = value.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  DateTime _arrivalDateTime() {
    final now = DateTime.now();
    var arrival = DateTime(
      now.year,
      now.month,
      now.day,
      arrivalTime.hour,
      arrivalTime.minute,
    );
    if (arrival.isBefore(now)) {
      arrival = arrival.add(const Duration(days: 1));
    }
    return arrival;
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '${hour}h$minute';
  }
}

enum _OperationalReservationMode { preReserve, paidReservation }

enum _OperationalPaymentMethod {
  cash('cash'),
  pix('pix'),
  card('card');

  final String apiValue;

  const _OperationalPaymentMethod(this.apiValue);
}

enum _OperationalPricingPlan {
  hourly('hourly'),
  daily('daily'),
  weekly('weekly'),
  monthly('monthly');

  final String apiValue;

  const _OperationalPricingPlan(this.apiValue);
}

enum _OperationalPayTiming { now, checkout }

class _CancelReservationDialog extends ConsumerStatefulWidget {
  final String reservationId;
  final bool checkedIn;
  final VoidCallback onCompleted;

  const _CancelReservationDialog({
    required this.reservationId,
    required this.checkedIn,
    required this.onCompleted,
  });

  @override
  ConsumerState<_CancelReservationDialog> createState() =>
      _CancelReservationDialogState();
}

class _CancelReservationDialogState
    extends ConsumerState<_CancelReservationDialog> {
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
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.checkedIn
                  ? 'Esta reserva ja teve check-in. Somente o gestor do parceiro pode cancelar.'
                  : 'Cancelamento em ate 5 minutos nao gera custo. Depois disso, aplica taxa administrativa configurada pelo gestor do app.',
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

class _CashierPaymentDialog extends ConsumerStatefulWidget {
  final String reservationId;
  final double amount;
  final VoidCallback onCompleted;

  const _CashierPaymentDialog({
    required this.reservationId,
    required this.amount,
    required this.onCompleted,
  });

  @override
  ConsumerState<_CashierPaymentDialog> createState() =>
      _CashierPaymentDialogState();
}

class _CashierPaymentDialogState extends ConsumerState<_CashierPaymentDialog> {
  final cashReceivedController = TextEditingController();
  _OperationalPaymentMethod paymentMethod = _OperationalPaymentMethod.cash;
  bool isSubmitting = false;
  String? pixQrCode;
  String? pendingPixPaymentId;
  double? changeAmount;

  @override
  void dispose() {
    cashReceivedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Caixa do estacionamento'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailLine('Total', 'R\$ ${widget.amount.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<_OperationalPaymentMethod>(
                initialValue: paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Forma de pagamento',
                ),
                items: const [
                  DropdownMenuItem(
                    value: _OperationalPaymentMethod.cash,
                    child: Text('Dinheiro'),
                  ),
                  DropdownMenuItem(
                    value: _OperationalPaymentMethod.pix,
                    child: Text('Pix'),
                  ),
                  DropdownMenuItem(
                    value: _OperationalPaymentMethod.card,
                    child: Text('Cartao - maquininha V2'),
                  ),
                ],
                onChanged: isSubmitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          paymentMethod = value;
                          pixQrCode = null;
                          pendingPixPaymentId = null;
                          changeAmount = null;
                        });
                      },
              ),
              if (paymentMethod == _OperationalPaymentMethod.cash) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: cashReceivedController,
                  enabled: !isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor recebido',
                    prefixText: 'R\$ ',
                  ),
                ),
              ],
              if (paymentMethod == _OperationalPaymentMethod.card) ...[
                const SizedBox(height: 12),
                const Text(
                  'Integracao com maquininha sera habilitada na V2.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ],
              if (changeAmount != null) ...[
                const SizedBox(height: 12),
                _DetailLine('Troco', 'R\$ ${changeAmount!.toStringAsFixed(2)}'),
              ],
              if (pixQrCode != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: QrImageView(
                    data: pixQrCode!,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  pixQrCode!,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed:
              !isSubmitting && paymentMethod != _OperationalPaymentMethod.card
              ? _receivePayment
              : null,
          icon: isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.point_of_sale),
          label: Text(
            pendingPixPaymentId != null
                ? 'Confirmar Pix pago'
                : paymentMethod == _OperationalPaymentMethod.pix
                ? 'Gerar QR Pix'
                : 'Receber',
          ),
        ),
      ],
    );
  }

  Future<void> _receivePayment() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;

    setState(() => isSubmitting = true);
    try {
      if (pendingPixPaymentId != null) {
        await confirmOperationalPayment(
          token: token,
          paymentId: pendingPixPaymentId!,
        );
        widget.onCompleted();
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pix confirmado no caixa.')),
        );
        return;
      }

      final payment = await createOperationalPaymentIntent(
        token: token,
        reservationId: widget.reservationId,
        method: paymentMethod.apiValue,
      );
      final total = (payment['gross_amount'] as num).toDouble();
      if (paymentMethod == _OperationalPaymentMethod.cash) {
        final received = _parseMoney(cashReceivedController.text);
        if (received < total) {
          throw Exception('Valor recebido menor que o total.');
        }
        await confirmOperationalPayment(
          token: token,
          paymentId: payment['id'] as String,
        );
        setState(() => changeAmount = received - total);
      } else {
        setState(() {
          pixQrCode = payment['qr_code'] as String?;
          pendingPixPaymentId = payment['id'] as String;
        });
        return;
      }

      widget.onCompleted();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pagamento recebido no caixa.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro no caixa: $error')));
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  double _parseMoney(String value) {
    final normalized = value.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }
}

class _CheckinPhotosDialog extends ConsumerStatefulWidget {
  final String reservationId;
  final VoidCallback onCompleted;

  const _CheckinPhotosDialog({
    required this.reservationId,
    required this.onCompleted,
  });

  @override
  ConsumerState<_CheckinPhotosDialog> createState() =>
      _CheckinPhotosDialogState();
}

class _CheckinPhotosDialogState extends ConsumerState<_CheckinPhotosDialog> {
  final Map<String, XFile?> photos = {
    'Frente': null,
    'Traseira': null,
    'Lateral esquerda': null,
    'Lateral direita': null,
  };
  bool isSubmitting = false;

  bool get hasAllPhotos => photos.values.every((photo) => photo != null);

  @override
  Widget build(BuildContext context) {
    final canUseCamera =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    return AlertDialog(
      title: const Text('Check-in com fotos'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Capture frente, traseira e laterais do veiculo antes de confirmar o check-in.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              for (final entry in photos.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed: canUseCamera && !isSubmitting
                        ? () => _takePhoto(entry.key)
                        : null,
                    icon: Icon(
                      entry.value == null
                          ? Icons.photo_camera_outlined
                          : Icons.check_circle,
                    ),
                    label: Text(entry.key),
                  ),
                ),
              if (!canUseCamera)
                const Text(
                  'O check-in com fotos deve ser feito no celular.',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: hasAllPhotos && !isSubmitting ? _confirmCheckin : null,
          icon: isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: const Text('Confirmar check-in'),
        ),
      ],
    );
  }

  Future<void> _takePhoto(String label) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => photos[label] = picked);
  }

  Future<void> _confirmCheckin() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;

    setState(() => isSubmitting = true);
    try {
      await checkinOperationalReservation(
        token: token,
        reservationId: widget.reservationId,
      );
      widget.onCompleted();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Check-in realizado.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao realizar check-in: $error')),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }
}

class _CheckoutPhotosDialog extends ConsumerStatefulWidget {
  final String reservationId;
  final VoidCallback onCompleted;

  const _CheckoutPhotosDialog({
    required this.reservationId,
    required this.onCompleted,
  });

  @override
  ConsumerState<_CheckoutPhotosDialog> createState() =>
      _CheckoutPhotosDialogState();
}

class _CheckoutPhotosDialogState extends ConsumerState<_CheckoutPhotosDialog> {
  final Map<String, XFile?> photos = {
    'Frente': null,
    'Traseira': null,
    'Lateral esquerda': null,
    'Lateral direita': null,
  };
  bool isSubmitting = false;

  bool get hasAllPhotos => photos.values.every((photo) => photo != null);

  @override
  Widget build(BuildContext context) {
    final canUseCamera =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    return AlertDialog(
      title: const Text('Checkout com fotos'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Capture frente, traseira e laterais do veiculo antes de liberar a vaga.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              for (final entry in photos.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed: canUseCamera && !isSubmitting
                        ? () => _takePhoto(entry.key)
                        : null,
                    icon: Icon(
                      entry.value == null
                          ? Icons.photo_camera_outlined
                          : Icons.check_circle,
                    ),
                    label: Text(entry.key),
                  ),
                ),
              if (!canUseCamera)
                const Text(
                  'O checkout com fotos deve ser feito no celular.',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: hasAllPhotos && !isSubmitting ? _confirmCheckout : null,
          icon: isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout),
          label: const Text('Confirmar checkout'),
        ),
      ],
    );
  }

  Future<void> _takePhoto(String label) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => photos[label] = picked);
  }

  Future<void> _confirmCheckout() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;

    setState(() => isSubmitting = true);
    try {
      await checkoutOperationalReservation(
        token: token,
        reservationId: widget.reservationId,
      );
      widget.onCompleted();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Checkout realizado.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao realizar checkout: $error')),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }
}

class _MoneySummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final int? count;
  final Color color;
  final String tooltip;

  const _MoneySummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    this.count,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width >= 900
          ? 220
          : MediaQuery.sizeOf(context).width - 52,
      height: 104,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                    Tooltip(
                      message: tooltip,
                      triggerMode: TooltipTriggerMode.tap,
                      child: Icon(Icons.info_outline, color: color, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'R\$ ${value.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$count reservas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _slotTypeLabel(String type) {
  return switch (type) {
    'covered' => 'Coberta',
    'vip' => 'VIP',
    'large' => 'Carro grande',
    'bus' => 'Onibus',
    'pickup' => 'Picape',
    _ => 'Descoberta',
  };
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
