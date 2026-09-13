import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/partner_profile_model.dart';
import '../models/partner_operational_models.dart';
import '../providers/partner_operations_provider.dart';
import '../providers/partner_profile_provider.dart';

/// Finance Pro uses the same entitlement that the platform admin configures.
/// Basic cash operations remain available from PartnerCashReportPage.
class PartnerFinancialPage extends ConsumerWidget {
  const PartnerFinancialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final profile = ref.watch(partnerProfileProvider);
    return Scaffold(
      appBar: AppBar(title: Text(isEnglish ? 'Finance Pro' : 'Financeiro Pro')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '${isEnglish ? 'Could not load access' : 'Não foi possível carregar o acesso'}: $error',
            ),
          ),
        ),
        data: (partner) {
          if (partner.role == 'operator') {
            return Center(
              child: Text(
                isEnglish
                    ? 'This report is available to the partner manager.'
                    : 'Este relatório está disponível para o gestor do parceiro.',
                textAlign: TextAlign.center,
              ),
            );
          }
          if (!partner.hasFeature('financial_management')) {
            return _LockedFeature(partner: partner, isEnglish: isEnglish);
          }
          return const _EnabledFinancialReport();
        },
      ),
    );
  }
}

class _LockedFeature extends StatelessWidget {
  const _LockedFeature({required this.partner, required this.isEnglish});

  final PartnerProfileModel partner;
  final bool isEnglish;

  @override
  Widget build(BuildContext context) {
    final details = partner.featureDetails('financial_management');
    final price = (details?['price'] as num? ?? 0).toDouble();
    final isPaid = details?['is_paid'] == true;
    final period = switch (details?['billing_period']) {
      'annual' => isEnglish ? 'year' : 'ano',
      'one_time' => isEnglish ? 'one time' : 'pagamento único',
      _ => isEnglish ? 'month' : 'mês',
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.softCyan,
                    foregroundColor: AppTheme.primary,
                    child: Icon(Icons.lock_outline),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isEnglish
                        ? 'Finance Pro add-on'
                        : 'Complemento Financeiro Pro',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isEnglish
                        ? 'Basic cash operations and the operating dashboard remain included. Pro adds reservation and payment reports by period, including received amounts and administrative fees.'
                        : 'O caixa básico e o dashboard operacional continuam incluídos. O Pro acrescenta relatórios de reservas e pagamentos por período, com valores recebidos e taxas administrativas.',
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                  if (isPaid) ...[
                    const SizedBox(height: 16),
                    Text(
                      '${isEnglish ? 'Configured price' : 'Preço configurado'}: R\$ ${price.toStringAsFixed(2)} / $period',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    isEnglish
                        ? 'Ask the ParkHere team to activate this add-on. In-app billing and automatic activation are not connected yet.'
                        : 'Solicite a ativação à equipe ParkHere. A cobrança no app e a ativação automática ainda não estão integradas.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EnabledFinancialReport extends ConsumerStatefulWidget {
  const _EnabledFinancialReport();

  @override
  ConsumerState<_EnabledFinancialReport> createState() =>
      _EnabledFinancialReportState();
}

class _EnabledFinancialReportState
    extends ConsumerState<_EnabledFinancialReport> {
  int _periodDays = 30;

  @override
  Widget build(BuildContext context) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final reservations = ref.watch(partnerFinancialReportProvider);
    return reservations.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '${isEnglish ? 'Report unavailable' : 'Relatório indisponível'}: $error',
          ),
        ),
      ),
      data: (items) {
        final now = DateTime.now();
        final filtered = items.where((item) {
          if (_periodDays == 0) return true;
          final start = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: _periodDays - 1));
          return !item.createdAt.toLocal().isBefore(start);
        }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final paid = filtered.where((item) => item.paymentStatus == 'paid');
        final received = paid.fold<double>(
          0,
          (sum, item) => sum + item.finalTotal,
        );
        final adminFees = paid.fold<double>(
          0,
          (sum, item) => sum + item.platformFeeAmount,
        );

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(partnerFinancialReportProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                isEnglish
                    ? 'Reservation and payment report'
                    : 'Relatório de reservas e pagamentos',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 1,
                    label: Text(isEnglish ? 'Today' : 'Hoje'),
                  ),
                  ButtonSegment(
                    value: 30,
                    label: Text(isEnglish ? '30 days' : '30 dias'),
                  ),
                  ButtonSegment(
                    value: 0,
                    label: Text(isEnglish ? 'All' : 'Tudo'),
                  ),
                ],
                selected: {_periodDays},
                onSelectionChanged: (selected) =>
                    setState(() => _periodDays = selected.first),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetricCard(
                    label: isEnglish ? 'Received' : 'Recebido',
                    value: _money(received),
                    icon: Icons.payments_outlined,
                  ),
                  _MetricCard(
                    label: isEnglish
                        ? 'Administrative fees'
                        : 'Taxas administrativas',
                    value: _money(adminFees),
                    icon: Icons.receipt_long_outlined,
                  ),
                  _MetricCard(
                    label: isEnglish ? 'Paid reservations' : 'Reservas pagas',
                    value: '${paid.length}',
                    icon: Icons.event_available_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(
                    isEnglish ? 'Operational report' : 'Relatório operacional',
                  ),
                  subtitle: Text(
                    isEnglish
                        ? 'Amounts come from reservation records. Provider settlement and bank reconciliation are not available in this module yet.'
                        : 'Os valores vêm dos registros de reservas. Repasse do provedor e conciliação bancária ainda não fazem parte deste módulo.',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final item in filtered.take(50))
                _ReservationRow(item: item, isEnglish: isEnglish),
              if (filtered.isEmpty)
                Card(
                  child: ListTile(
                    title: Text(
                      isEnglish
                          ? 'No reservations in this period.'
                          : 'Nenhuma reserva neste período.',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(label),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    ),
  );
}

class _ReservationRow extends StatelessWidget {
  const _ReservationRow({required this.item, required this.isEnglish});
  final PartnerReservationSummary item;
  final bool isEnglish;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        item.paymentStatus == 'paid'
            ? Icons.check_circle_outline
            : Icons.schedule,
      ),
      title: Text(
        '${item.parkingName} · ${item.vehiclePlate ?? (isEnglish ? 'No plate' : 'Sem placa')}',
      ),
      subtitle: Text(
        '${_formatDateTime(item.createdAt.toLocal())} · ${_statusLabel(item.status, isEnglish)} · ${_paymentLabel(item.paymentStatus, isEnglish)}',
      ),
      isThreeLine: true,
      trailing: SizedBox(
        width: 104,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _money(item.finalTotal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${isEnglish ? 'App fee' : 'Taxa app'} ${_money(item.platformFeeAmount)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    ),
  );
}

String _money(double value) => 'R\$ ${value.toStringAsFixed(2)}';

String _formatDateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _statusLabel(String value, bool isEnglish) {
  const pt = {
    'pre_reserved': 'Pré-reserva',
    'confirmed': 'Confirmada',
    'checked_in': 'Em andamento',
    'completed': 'Finalizada',
    'cancelled': 'Cancelada',
    'expired': 'Expirada',
  };
  const en = {
    'pre_reserved': 'Pre-reserved',
    'confirmed': 'Confirmed',
    'checked_in': 'In progress',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
    'expired': 'Expired',
  };
  return (isEnglish ? en : pt)[value] ?? value;
}

String _paymentLabel(String value, bool isEnglish) {
  const pt = {
    'paid': 'Pago',
    'pending': 'Pendente',
    'failed': 'Falhou',
    'refunded': 'Estornado',
  };
  const en = {
    'paid': 'Paid',
    'pending': 'Pending',
    'failed': 'Failed',
    'refunded': 'Refunded',
  };
  return (isEnglish ? en : pt)[value] ?? value;
}
