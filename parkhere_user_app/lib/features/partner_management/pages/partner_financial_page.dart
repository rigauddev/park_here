import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
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
  DateTime? _startDate;
  DateTime? _endDate;
  int? _periodDays;
  String _selectedFilter = 'month'; // 'month', 'today', '7d', '30d', 'all', 'custom'
  String _parkingSubFilter = 'paid'; // 'all', 'paid', 'refunded', 'cancelled'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  FinancialFilterParams get _filterParams {
    String? sStr;
    String? eStr;
    if (_startDate != null) {
      sStr = '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}';
    }
    if (_endDate != null) {
      eStr = '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}';
    }
    return FinancialFilterParams(
      startDate: sStr,
      endDate: eStr,
      periodDays: _periodDays,
    );
  }

  String get _periodDisplay {
    if (_startDate != null && _endDate != null) {
      return '${_startDate!.day.toString().padLeft(2, '0')}/${_startDate!.month.toString().padLeft(2, '0')} - ${_endDate!.day.toString().padLeft(2, '0')}/${_endDate!.month.toString().padLeft(2, '0')}/${_endDate!.year}';
    }
    if (_periodDays == 1) return 'Hoje';
    if (_periodDays == 7) return 'Últimos 7 dias';
    if (_periodDays == 30) return 'Últimos 30 dias';
    if (_periodDays == 0) return 'Todo o histórico';
    return 'Mês atual';
  }

  Future<void> _selectCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month + 1, 0)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _periodDays = null;
        _selectedFilter = 'custom';
      });
    }
  }

  void _applyQuickFilter(String key) {
    final now = DateTime.now();
    setState(() {
      _selectedFilter = key;
      switch (key) {
        case 'month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          _periodDays = null;
          break;
        case 'today':
          _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          _periodDays = null;
          break;
        case '7d':
          _startDate = null;
          _endDate = null;
          _periodDays = 7;
          break;
        case '30d':
          _startDate = null;
          _endDate = null;
          _periodDays = 30;
          break;
        case 'all':
          _startDate = null;
          _endDate = null;
          _periodDays = 0;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final params = _filterParams;
    final summaryAsync = ref.watch(partnerFilteredFinancialSummaryProvider(params));
    final reservationsAsync = ref.watch(partnerFinancialReportProvider);
    final entriesAsync = ref.watch(partnerFinancialEntriesProvider(params));
    final costCentersAsync = ref.watch(partnerCostCentersProvider);

    return Column(
      children: [
        // Top filter bar with calendar and quick chips
        Container(
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: _selectCustomRange,
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(
                      _periodDisplay,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Atualizar dados',
                    onPressed: () {
                      ref.invalidate(partnerFilteredFinancialSummaryProvider(params));
                      ref.invalidate(partnerFinancialReportProvider);
                      ref.invalidate(partnerFinancialEntriesProvider(params));
                      ref.invalidate(partnerCostCentersProvider);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('Mês Atual', 'month'),
                    const SizedBox(width: 6),
                    _filterChip('Hoje', 'today'),
                    const SizedBox(width: 6),
                    _filterChip('7 dias', '7d'),
                    const SizedBox(width: 6),
                    _filterChip('30 dias', '30d'),
                    const SizedBox(width: 6),
                    _filterChip('Tudo', 'all'),
                    if (_selectedFilter == 'custom') ...[
                      const SizedBox(width: 6),
                      _filterChip('Personalizado', 'custom'),
                    ],
                  ],
                ),
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
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Consolidado'),
            Tab(icon: Icon(Icons.local_parking_outlined), text: 'Estacionamento'),
            Tab(icon: Icon(Icons.storefront_outlined), text: 'Conveniência'),
            Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Lançamentos & Custos'),
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
                  _buildEntriesTab(entriesAsync, params, costCentersAsync),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String key) {
    final selected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _applyQuickFilter(key),
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
        ref.invalidate(partnerFilteredFinancialSummaryProvider(_filterParams));
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
        ref.invalidate(partnerFilteredFinancialSummaryProvider(_filterParams));
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
                final dt = item.createdAt.toLocal();
                if (_startDate != null && dt.isBefore(_startDate!)) return false;
                if (_endDate != null && dt.isAfter(_endDate!)) return false;
                if (_periodDays != null && _periodDays! > 0) {
                  final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: _periodDays! - 1));
                  return !dt.isBefore(start);
                }
                return true;
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
        ref.invalidate(partnerFilteredFinancialSummaryProvider(_filterParams));
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

  // --- TAB 4: LANÇAMENTOS E CENTROS DE CUSTO ---
  Widget _buildEntriesTab(
    AsyncValue<List<Map<String, dynamic>>> entriesAsync,
    FinancialFilterParams params,
    AsyncValue<List<Map<String, dynamic>>> costCentersAsync,
  ) {
    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erro ao carregar lançamentos: $err'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(partnerFinancialEntriesProvider(params)),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
      data: (entries) {
        double totalIncomes = 0;
        double totalExpenses = 0;
        for (final entry in entries) {
          final amt = (entry['amount'] as num? ?? 0).toDouble();
          if (entry['entry_type'] == 'income') {
            totalIncomes += amt;
          } else {
            totalExpenses += amt;
          }
        }
        final netBalance = totalIncomes - totalExpenses;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(partnerFinancialEntriesProvider(params));
            ref.invalidate(partnerCostCentersProvider);
            ref.invalidate(partnerFilteredFinancialSummaryProvider(params));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Top actions bar
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    'Gestão de Caixa Manual',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showCostCentersDialog(costCentersAsync),
                        icon: const Icon(Icons.category_outlined, size: 16),
                        label: const Text('Centros de Custo'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.blue.shade900),
                        onPressed: () => _showNewEntryDialog(costCentersAsync),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Lançamento'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.arrow_upward, size: 16, color: Colors.green),
                                SizedBox(width: 4),
                                Text('Entradas', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(_money(totalIncomes), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.arrow_downward, size: 16, color: Colors.red),
                                SizedBox(width: 4),
                                Text('Saídas', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(_money(totalExpenses), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      color: netBalance >= 0 ? Colors.blue.shade50 : Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.balance, size: 16, color: netBalance >= 0 ? Colors.blue.shade900 : Colors.deepOrange),
                                const SizedBox(width: 4),
                                Text('Saldo', style: TextStyle(fontSize: 12, color: netBalance >= 0 ? Colors.blue.shade900 : Colors.deepOrange, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _money(netBalance),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: netBalance >= 0 ? Colors.blue.shade900 : Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                'Histórico de Lançamentos (${entries.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),

              if (entries.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textMuted),
                        const SizedBox(height: 8),
                        const Text('Nenhum lançamento no período selecionado.'),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showNewEntryDialog(costCentersAsync),
                          icon: const Icon(Icons.add),
                          label: const Text('Cadastrar Lançamento'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final entry in entries) _buildEntryCard(entry),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry) {
    final isIncome = entry['entry_type'] == 'income';
    final amount = (entry['amount'] as num? ?? 0).toDouble();
    final category = entry['category'] as String? ?? 'Geral';
    final desc = entry['description'] as String? ?? '';
    final ccName = entry['cost_center_name'] as String? ?? 'Geral';
    final ccCode = entry['cost_center_code'] as String?;
    final method = entry['payment_method'] as String? ?? 'outros';
    final createdBy = entry['created_by_name'] as String? ?? 'Gestor';
    final dateStr = entry['entry_date'] != null
        ? DateTime.tryParse(entry['entry_date'] as String)?.toLocal()
        : null;
    final formattedDate = dateStr != null
        ? '${dateStr.day.toString().padLeft(2, '0')}/${dateStr.month.toString().padLeft(2, '0')} ${dateStr.hour.toString().padLeft(2, '0')}:${dateStr.minute.toString().padLeft(2, '0')}'
        : '';

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
          foregroundColor: isIncome ? Colors.green.shade800 : Colors.red.shade800,
          child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                category,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ccCode != null && ccCode != '-' ? '$ccCode $ccName' : ccName,
                style: const TextStyle(fontSize: 10, color: Colors.black87),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (desc.isNotEmpty) Text(desc, style: const TextStyle(fontSize: 13)),
            Text(
              '$formattedDate · ${_paymentText(method)} · Por: $createdBy',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'} ${_money(amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
      ),
    );
  }

  Future<void> _showNewEntryDialog(
    AsyncValue<List<Map<String, dynamic>>> costCentersAsync,
  ) async {
    final costCenters = costCentersAsync.asData?.value ?? [];
    String entryType = 'expense';
    String? selectedCostCenterId = costCenters.isNotEmpty ? costCenters.first['id'] as String? : null;
    final categoryCtrl = TextEditingController(text: 'Manutenção');
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String paymentMethod = 'pix';
    DateTime selectedDate = DateTime.now();
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Novo Lançamento Financeiro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type selector
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'expense',
                      label: Text('Saída / Despesa'),
                      icon: Icon(Icons.arrow_downward, color: Colors.red),
                    ),
                    ButtonSegment(
                      value: 'income',
                      label: Text('Entrada / Receita'),
                      icon: Icon(Icons.arrow_upward, color: Colors.green),
                    ),
                  ],
                  selected: {entryType},
                  onSelectionChanged: (val) {
                    setDialogState(() {
                      entryType = val.first;
                      if (entryType == 'income') {
                        categoryCtrl.text = 'Receita Extra';
                      } else {
                        categoryCtrl.text = 'Manutenção';
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Cost center dropdown
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Centro de Custo *',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: selectedCostCenterId,
                  items: [
                    for (final cc in costCenters)
                      DropdownMenuItem<String>(
                        value: cc['id'] as String?,
                        child: Text('${cc['code'] ?? ''} ${cc['name']}'.trim()),
                      ),
                  ],
                  onChanged: (val) => setDialogState(() => selectedCostCenterId = val),
                ),
                const SizedBox(height: 12),

                // Category
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Categoria *',
                    hintText: 'Ex: Aluguel, Limpeza, Manutenção, Salários',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descrição detalhada *',
                    hintText: 'Ex: Compra de bobinas para impressora',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Amount
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: r'Valor (R$) *',
                    prefixText: r'R$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Payment Method
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Forma de Pagamento *',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: paymentMethod,
                  items: const [
                    DropdownMenuItem(value: 'pix', child: Text('PIX')),
                    DropdownMenuItem(value: 'cash', child: Text('Dinheiro')),
                    DropdownMenuItem(value: 'credit_card', child: Text('Cartão de Crédito')),
                    DropdownMenuItem(value: 'debit_card', child: Text('Cartão de Débito')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Transferência Bancária')),
                    DropdownMenuItem(value: 'other', child: Text('Outros')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => paymentMethod = val);
                  },
                ),
                const SizedBox(height: 12),

                // Date picker
                Row(
                  children: [
                    const Icon(Icons.event, size: 20, color: AppTheme.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Data: ${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: const Text('Alterar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: entryType == 'income' ? Colors.green.shade800 : Colors.red.shade800,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                      final category = categoryCtrl.text.trim();
                      final desc = descCtrl.text.trim();

                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Informe um valor válido.')),
                        );
                        return;
                      }
                      if (category.isEmpty || desc.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Preencha categoria e descrição.')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        final token = ref.read(authProvider).accessToken;
                        if (token == null) throw Exception('Sessão expirada');

                        await createPartnerFinancialEntry(
                          token: token,
                          entryType: entryType,
                          category: category,
                          description: desc,
                          amount: amount,
                          paymentMethod: paymentMethod,
                          costCenterId: selectedCostCenterId,
                          entryDate: selectedDate,
                        );

                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);

                        // Refresh providers
                        ref.invalidate(partnerFinancialEntriesProvider(_filterParams));
                        ref.invalidate(partnerFilteredFinancialSummaryProvider(_filterParams));

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lançamento de ${entryType == 'income' ? 'receita' : 'despesa'} criado com sucesso!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erro ao salvar lançamento: $e')),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Salvar Lançamento'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCostCentersDialog(
    AsyncValue<List<Map<String, dynamic>>> costCentersAsync,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final centers = ref.watch(partnerCostCentersProvider).asData?.value ?? [];
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.category, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Centros de Custo'),
                const Spacer(),
                IconButton(
                  tooltip: 'Novo Centro de Custo',
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () async {
                    await _showNewCostCenterDialog();
                    setModalState(() {});
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: centers.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Nenhum centro de custo cadastrado.'),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: centers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (c, idx) {
                        final cc = centers[idx];
                        final code = cc['code'] as String?;
                        final name = cc['name'] as String? ?? '';
                        final type = cc['type'] as String? ?? 'both';
                        final typeLabel = switch (type) {
                          'revenue' => 'Receita',
                          'expense' => 'Despesa',
                          _ => 'Ambos',
                        };

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('$name ${code != null ? '($code)' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('Tipo: $typeLabel'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            tooltip: 'Desativar',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: ctx,
                                builder: (_) => AlertDialog(
                                  title: const Text('Desativar Centro de Custo?'),
                                  content: Text('Deseja realmente desativar o centro de custo "$name"?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Desativar'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final token = ref.read(authProvider).accessToken;
                                if (token != null) {
                                  await deactivatePartnerCostCenter(token: token, costCenterId: cc['id'] as String);
                                  ref.invalidate(partnerCostCentersProvider);
                                  setModalState(() {});
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showNewCostCenterDialog() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String type = 'both';
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Novo Centro de Custo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome do Centro de Custo *',
                  hintText: 'Ex: Operacional, Administrativo, TI',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código identificador (opcional)',
                  hintText: 'Ex: CC-01, ADM, OPR',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Tipo de Lançamento *',
                  border: OutlineInputBorder(),
                ),
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'both', child: Text('Receitas e Despesas (Misto)')),
                  DropdownMenuItem(value: 'expense', child: Text('Apenas Despesas')),
                  DropdownMenuItem(value: 'revenue', child: Text('Apenas Receitas')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => type = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Informe o nome do centro de custo.')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        final token = ref.read(authProvider).accessToken;
                        if (token == null) throw Exception('Sessão expirada');

                        await createPartnerCostCenter(
                          token: token,
                          name: name,
                          code: codeCtrl.text.trim().isNotEmpty ? codeCtrl.text.trim() : null,
                          type: type,
                        );

                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);

                        ref.invalidate(partnerCostCentersProvider);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Centro de custo criado com sucesso!'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erro ao criar centro de custo: $e')),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Criar Centro de Custo'),
            ),
          ],
        ),
      ),
    );
  }

  String _money(double value) => 'R\$ ${value.toStringAsFixed(2)}';

  String _paymentText(String p) => switch (p) {
        'paid' => 'Pago',
        'pending' => 'Pendente',
        'refunded' => 'Estornado',
        'refunded_pending' => 'Estorno pendente',
        'failed' => 'Falhou',
        'pix' => 'PIX',
        'cash' => 'Dinheiro',
        'credit_card' => 'Cartão de Crédito',
        'debit_card' => 'Cartão de Débito',
        'bank_transfer' => 'Transferência',
        _ => p,
      };
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
