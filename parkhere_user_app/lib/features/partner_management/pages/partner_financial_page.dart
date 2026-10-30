import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/partner_profile_model.dart';
import '../models/partner_operational_models.dart';
import '../providers/partner_operations_provider.dart';
import '../providers/partner_profile_provider.dart';

class PartnerFinancialPage extends ConsumerWidget {
  const PartnerFinancialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final profile = ref.watch(partnerProfileProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(isEnglish ? 'Financial Dashboard' : 'Painel Financeiro Pro'),
      ),
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
          return const _FinancialDashboardView();
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
                        : 'Módulo Financeiro Pro',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isEnglish
                        ? 'Basic cash operations and the operating dashboard remain included. Pro adds reservation and payment reports by period, including received amounts and administrative fees.'
                        : 'O caixa básico e o dashboard operacional continuam incluídos. O módulo Pro adiciona relatórios completos com separação de receitas de estacionamento e conveniência, estornos e conciliação.',
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
                        ? 'Ask the ParkHere team to activate this add-on.'
                        : 'Solicite a ativação à equipe ParkHere caso queira liberar esta funcionalidade.',
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

class _FinancialDashboardView extends ConsumerStatefulWidget {
  const _FinancialDashboardView();

  @override
  ConsumerState<_FinancialDashboardView> createState() =>
      _FinancialDashboardViewState();
}

class _FinancialDashboardViewState
    extends ConsumerState<_FinancialDashboardView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _periodDays = 30; // 1, 7, 30, 0 (all)
  String _parkingSubFilter = 'paid'; // 'all', 'paid', 'refunded', 'cancelled'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(partnerFinancialSummaryProvider(_periodDays));
    final reservationsAsync = ref.watch(partnerFinancialReportProvider);

    return Column(
      children: [
        // Top filter bar
        Container(
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.date_range, size: 20, color: AppTheme.textMuted),
              const SizedBox(width: 8),
              const Text('Período:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _periodChip('Hoje', 1),
                      const SizedBox(width: 6),
                      _periodChip('7 dias', 7),
                      const SizedBox(width: 6),
                      _periodChip('30 dias', 30),
                      const SizedBox(width: 6),
                      _periodChip('Tudo', 0),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Atualizar dados',
                onPressed: () {
                  ref.invalidate(partnerFinancialSummaryProvider(_periodDays));
                  ref.invalidate(partnerFinancialReportProvider);
                },
              ),
            ],
          ),
        ),

        // Tabs
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Consolidado'),
            Tab(icon: Icon(Icons.local_parking_outlined), text: 'Estacionamento'),
            Tab(icon: Icon(Icons.storefront_outlined), text: 'Conveniência'),
          ],
        ),

        // Content
        Expanded(
          child: summaryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text('Erro ao carregar resumo: $err'),
            ),
            data: (summary) {
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildConsolidatedTab(summary),
                  _buildParkingTab(summary, reservationsAsync),
                  _buildConvenienceTab(summary),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _periodChip(String label, int days) {
    final selected = _periodDays == days;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) setState(() => _periodDays = days);
      },
    );
  }

  // --- TAB 1: CONSOLIDADO ---
  Widget _buildConsolidatedTab(Map<String, dynamic> summary) {
    final consolidated = summary['consolidated'] as Map<String, dynamic>? ?? {};
    final parking = summary['parking'] as Map<String, dynamic>? ?? {};
    final convenience = summary['convenience'] as Map<String, dynamic>? ?? {};

    final totalGross = (consolidated['total_gross_revenue'] as num? ?? 0).toDouble();
    final totalRefunds = (consolidated['total_refunds'] as num? ?? 0).toDouble();
    final totalFees = (consolidated['total_platform_fees'] as num? ?? 0).toDouble();
    final totalNet = (consolidated['total_net_revenue'] as num? ?? 0).toDouble();
    final totalOps = consolidated['total_operations'] as int? ?? 0;

    final parkingGross = (parking['gross_revenue'] as num? ?? 0).toDouble();
    final convGross = (convenience['gross_revenue'] as num? ?? 0).toDouble();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(partnerFinancialSummaryProvider(_periodDays));
        ref.invalidate(partnerFinancialReportProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Visão Geral Financeira',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Resultados combinados de estacionamento e loja de conveniência.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),

          // Primary Net Revenue Highlight
          Card(
            color: Colors.blue.shade900,
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: Colors.white70),
                      SizedBox(width: 8),
                      Text(
                        'RECEITA LÍQUIDA REAL',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _money(totalNet),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total de $totalOps operações concluídas no período.',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Grid of secondary metrics
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricBox(
                label: 'Receita Bruta (Entradas)',
                value: _money(totalGross),
                icon: Icons.trending_up,
                color: Colors.green.shade700,
                subtitle: 'Total faturado no período',
              ),
              _metricBox(
                label: 'Estornos & Devoluções',
                value: _money(totalRefunds),
                icon: Icons.trending_down,
                color: Colors.red.shade700,
                subtitle: 'Saídas efetivas de caixa',
              ),
              _metricBox(
                label: 'Taxas da Plataforma',
                value: _money(totalFees),
                icon: Icons.receipt_long,
                color: Colors.purple.shade700,
                subtitle: 'Taxas administrativas app',
              ),
              _metricBox(
                label: 'Ticket Médio Combinado',
                value: _money(totalOps > 0 ? (totalGross / totalOps) : 0),
                icon: Icons.analytics_outlined,
                color: Colors.blue.shade700,
                subtitle: 'Média por operação',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Breakdown by source
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Distribuição de Faturamento por Origem',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  _breakdownRow(
                    label: 'Estacionamento (Reservas & Vagas)',
                    amount: parkingGross,
                    total: totalGross,
                    color: Colors.indigo,
                    icon: Icons.local_parking,
                  ),
                  const SizedBox(height: 12),
                  _breakdownRow(
                    label: 'Conveniência & Loja (PDV)',
                    amount: convGross,
                    total: totalGross,
                    color: Colors.teal,
                    icon: Icons.storefront,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: ESTACIONAMENTO ---
  Widget _buildParkingTab(
    Map<String, dynamic> summary,
    AsyncValue<List<PartnerReservationSummary>> reservationsAsync,
  ) {
    final parking = summary['parking'] as Map<String, dynamic>? ?? {};
    final gross = (parking['gross_revenue'] as num? ?? 0).toDouble();
    final refunds = (parking['refunds_amount'] as num? ?? 0).toDouble();
    final fees = (parking['platform_fees'] as num? ?? 0).toDouble();
    final net = (parking['net_revenue'] as num? ?? 0).toDouble();
    final paidCount = parking['paid_count'] as int? ?? 0;
    final refundedCount = parking['refunded_count'] as int? ?? 0;
    final cancelledCount = parking['cancelled_count'] as int? ?? 0;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(partnerFinancialSummaryProvider(_periodDays));
        ref.invalidate(partnerFinancialReportProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(Icons.local_parking, color: Colors.indigo),
              const SizedBox(width: 8),
              Text(
                'Financeiro do Estacionamento',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Parking Metrics
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricBox(
                label: 'Receita Bruta (Pagas)',
                value: _money(gross),
                icon: Icons.check_circle_outline,
                color: Colors.green.shade700,
                subtitle: '$paidCount reservas pagas',
              ),
              _metricBox(
                label: 'Estornos Reais (Saídas)',
                value: _money(refunds),
                icon: Icons.undo,
                color: Colors.red.shade700,
                subtitle: '$refundedCount estornos efetuados',
              ),
              _metricBox(
                label: 'Taxas App Retidas',
                value: _money(fees),
                icon: Icons.receipt,
                color: Colors.purple.shade700,
                subtitle: 'Comissão da plataforma',
              ),
              _metricBox(
                label: 'Líquido Estacionamento',
                value: _money(net),
                icon: Icons.account_balance,
                color: Colors.indigo.shade700,
                subtitle: 'Receita líquida da unidade',
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Informational Alert about Cancelled without Refund
          Card(
            color: Colors.amber.shade50,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.amber.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reservas Canceladas ($cancelledCount no período):'
                      '\nNão afetam o fluxo financeiro diretamente pois não houve cobrança ou estorno.',
                      style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Sub-filters for transactions list
          Row(
            children: [
              const Text('Transações:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              FilterChip(
                label: Text('Pagas ($paidCount)'),
                selected: _parkingSubFilter == 'paid',
                onSelected: (v) => setState(() => _parkingSubFilter = 'paid'),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: Text('Estornos ($refundedCount)'),
                selected: _parkingSubFilter == 'refunded',
                onSelected: (v) => setState(() => _parkingSubFilter = 'refunded'),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: Text('Canceladas ($cancelledCount)'),
                selected: _parkingSubFilter == 'cancelled',
                onSelected: (v) => setState(() => _parkingSubFilter = 'cancelled'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Detailed List of Reservations
          reservationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erro ao carregar detalhes: $e'),
            data: (items) {
              final now = DateTime.now();
              final filteredByDate = items.where((item) {
                if (_periodDays == 0) return true;
                final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: _periodDays - 1));
                return !item.createdAt.toLocal().isBefore(start);
              }).toList();

              final list = filteredByDate.where((item) {
                if (_parkingSubFilter == 'paid') {
                  return item.paymentStatus == 'paid';
                } else if (_parkingSubFilter == 'refunded') {
                  return item.paymentStatus == 'refunded' || item.paymentStatus == 'refunded_pending';
                } else if (_parkingSubFilter == 'cancelled') {
                  return item.status == 'cancelled' && item.paymentStatus != 'refunded';
                }
                return true;
              }).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              if (list.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Nenhuma reserva nesta categoria.')),
                  ),
                );
              }

              return Column(
                children: [
                  for (final item in list.take(30))
                    _ReservationRow(item: item),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- TAB 3: CONVENIÊNCIA ---
  Widget _buildConvenienceTab(Map<String, dynamic> summary) {
    final convenience = summary['convenience'] as Map<String, dynamic>? ?? {};
    final gross = (convenience['gross_revenue'] as num? ?? 0).toDouble();
    final discounts = (convenience['discounts_given'] as num? ?? 0).toDouble();
    final cancelledAmount = (convenience['cancelled_amount'] as num? ?? 0).toDouble();
    final net = (convenience['net_revenue'] as num? ?? 0).toDouble();
    final completedCount = convenience['completed_count'] as int? ?? 0;
    final cancelledCount = convenience['cancelled_count'] as int? ?? 0;
    final avgTicket = (convenience['average_ticket'] as num? ?? 0).toDouble();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(partnerFinancialSummaryProvider(_periodDays));
        ref.invalidate(partnerFinancialReportProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(Icons.storefront, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                'Financeiro da Conveniência & Loja',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricBox(
                label: 'Receita Bruta Concluída',
                value: _money(gross),
                icon: Icons.point_of_sale,
                color: Colors.teal.shade700,
                subtitle: '$completedCount vendas finalizadas',
              ),
              _metricBox(
                label: 'Vendas Canceladas (Estornos)',
                value: _money(cancelledAmount),
                icon: Icons.cancel_outlined,
                color: Colors.red.shade700,
                subtitle: '$cancelledCount vendas canceladas',
              ),
              _metricBox(
                label: 'Descontos Concedidos',
                value: _money(discounts),
                icon: Icons.percent,
                color: Colors.orange.shade700,
                subtitle: 'Total de desconto no PDV',
              ),
              _metricBox(
                label: 'Líquido Conveniência',
                value: _money(net),
                icon: Icons.account_balance_wallet,
                color: Colors.blueGrey.shade800,
                subtitle: 'Receita líquida da loja',
              ),
            ],
          ),

          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Indicadores de Performance da Loja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.analytics, color: Colors.teal),
                    title: const Text('Ticket Médio por Venda'),
                    trailing: Text(_money(avgTicket), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.verified, color: Colors.green),
                    title: const Text('Taxa de Conclusão'),
                    trailing: Text(
                      completedCount + cancelledCount > 0
                          ? '${((completedCount / (completedCount + cancelledCount)) * 100).toStringAsFixed(1)}%'
                          : '100%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBox({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 1.5,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withValues(alpha: 0.12),
                    foregroundColor: color,
                    child: Icon(icon, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _breakdownRow({
    required String label,
    required double amount,
    required double total,
    required Color color,
    required IconData icon,
  }) {
    final pct = total > 0 ? (amount / total) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(_money(amount), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text('(${(pct * 100).toStringAsFixed(1)}%)', style: const TextStyle(color: AppTheme.textMuted)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: pct.clamp(0.0, 1.0),
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  String _money(double value) => 'R\$ ${value.toStringAsFixed(2)}';
}

class _ReservationRow extends StatelessWidget {
  const _ReservationRow({required this.item});
  final PartnerReservationSummary item;

  @override
  Widget build(BuildContext context) {
    final isPaid = item.paymentStatus == 'paid';
    final isRefunded = item.paymentStatus == 'refunded' || item.paymentStatus == 'refunded_pending';
    final isCancelled = item.status == 'cancelled';

    final Color statusColor = isRefunded
        ? Colors.red
        : (isPaid ? Colors.green : (isCancelled ? Colors.amber.shade800 : Colors.blue));

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          foregroundColor: statusColor,
          child: Icon(isRefunded ? Icons.undo : (isPaid ? Icons.check : Icons.schedule)),
        ),
        title: Text(
          '${item.parkingName} · ${item.vehiclePlate ?? 'Sem placa'}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${_formatDate(item.createdAt.toLocal())} · ${_statusText(item.status)} · ${_paymentText(item.paymentStatus)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'R\$ ${item.finalTotal.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isRefunded ? Colors.red : null),
            ),
            if (item.platformFeeAmount > 0)
              Text(
                'Taxa: R\$ ${item.platformFeeAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _statusText(String s) => switch (s) {
        'pre_reserved' => 'Pré-reserva',
        'confirmed' => 'Confirmada',
        'checked_in' => 'Em andamento',
        'completed' => 'Finalizada',
        'cancelled' => 'Cancelada',
        'expired' => 'Expirada',
        _ => s,
      };

  String _paymentText(String p) => switch (p) {
        'paid' => 'Pago',
        'pending' => 'Pendente',
        'refunded' => 'Estornado',
        'refunded_pending' => 'Estorno pendente',
        'failed' => 'Falhou',
        _ => p,
      };
}
