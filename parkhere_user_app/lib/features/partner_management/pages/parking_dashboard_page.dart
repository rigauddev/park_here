import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/theme/app_theme.dart';

class ParkingDashboardPage extends StatefulWidget {
  const ParkingDashboardPage({super.key});

  @override
  State<ParkingDashboardPage> createState() => _ParkingDashboardPageState();
}

class _ParkingDashboardPageState extends State<ParkingDashboardPage> {
  DateTimeRange? _period;
  String? _parkingId;
  String _serviceType = 'all';
  late Future<Map<String, dynamic>> _future;

  bool get _isEnglish => Localizations.localeOf(context).languageCode == 'en';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final token = (await LocalStorageService().getTokens())['access'];
    if (token == null || token.isEmpty) {
      throw const ApiUnauthorizedException();
    }
    final params = <String, String>{'service_type': _serviceType};
    if (_period != null) {
      params['start'] = _dateString(_period!.start);
      params['end'] = _dateString(_period!.end);
    }
    if (_parkingId != null && _parkingId!.isNotEmpty) {
      params['parking_id'] = _parkingId!;
    }
    final query = Uri(queryParameters: params).query;
    return ApiService().getAuthorizedMap('/partners/dashboard?$query', token);
  }

  String _dateString(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final title = _isEnglish ? 'Partner overview' : 'Visão geral da empresa';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: _isEnglish ? 'Refresh' : 'Atualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error, onRetry: _refresh);
          }
          final data = snapshot.data ?? const <String, dynamic>{};
          return _DashboardBody(
            data: data,
            isEnglish: _isEnglish,
            period: _period,
            parkingId: _parkingId,
            serviceType: _serviceType,
            onPeriodChanged: (value) {
              setState(() {
                _period = value;
                _future = _load();
              });
            },
            onParkingChanged: (value) {
              setState(() {
                _parkingId = value;
                _future = _load();
              });
            },
            onServiceChanged: (value) {
              setState(() {
                _serviceType = value;
                _future = _load();
              });
            },
          );
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isEnglish;
  final DateTimeRange? period;
  final String? parkingId;
  final String serviceType;
  final ValueChanged<DateTimeRange?> onPeriodChanged;
  final ValueChanged<String?> onParkingChanged;
  final ValueChanged<String> onServiceChanged;

  const _DashboardBody({
    required this.data,
    required this.isEnglish,
    required this.period,
    required this.parkingId,
    required this.serviceType,
    required this.onPeriodChanged,
    required this.onParkingChanged,
    required this.onServiceChanged,
  });

  String _money(dynamic value) {
    final number = _number(value);
    return isEnglish
        ? 'R\$ ${number.toStringAsFixed(2)}'
        : 'R\$ ${number.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  int _integer(dynamic value) => _number(value).round();
  List<Map<String, dynamic>> _list(String key) =>
      (data[key] is List ? data[key] as List : const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
  Map<String, dynamic> _map(String key) =>
      data[key] is Map ? Map<String, dynamic>.from(data[key] as Map) : {};

  @override
  Widget build(BuildContext context) {
    final summary = _map('summary');
    final units = _list('units');
    final services = _list('additional_services');
    final convenience = _map('convenience');
    final convenienceCategories = convenience['categories'] is List
        ? (convenience['categories'] as List).whereType<Map>().toList()
        : const <Map>[];
    final modalities = _map('modality_breakdown');
    final monthly = _list('monthly');
    final cities = _list('customer_cities');
    final staffing = _list('staffing');
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100
        ? 4
        : width >= 700
        ? 2
        : 1;
    final dateText = period == null
        ? (isEnglish ? 'Last 30 days' : 'Últimos 30 dias')
        : '${period!.start.day.toString().padLeft(2, '0')}/${period!.start.month.toString().padLeft(2, '0')} – ${period!.end.day.toString().padLeft(2, '0')}/${period!.end.month.toString().padLeft(2, '0')}';

    return RefreshIndicator(
      onRefresh: () async {
        // The parent owns the future; pull-to-refresh reuses the current filters.
        onServiceChanged(serviceType);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          width < 600 ? 12 : 24,
          12,
          width < 600 ? 12 : 24,
          32,
        ),
        children: [
          _IntroCard(isEnglish: isEnglish, partner: _map('partner')),
          const SizedBox(height: 14),
          _FilterBar(
            isEnglish: isEnglish,
            dateText: dateText,
            period: period,
            parkingId: parkingId,
            serviceType: serviceType,
            units: units,
            onPeriodChanged: onPeriodChanged,
            onParkingChanged: onParkingChanged,
            onServiceChanged: onServiceChanged,
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: width < 600 ? 2.4 : 2.0,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _KpiCard(
                label: isEnglish ? 'Reservations' : 'Reservas',
                value: '${_integer(summary['reservations'])}',
                icon: Icons.event_available_rounded,
                color: AppTheme.primary,
              ),
              _KpiCard(
                label: isEnglish ? 'Paid revenue' : 'Faturamento recebido',
                value: _money(summary['paid_revenue']),
                icon: Icons.payments_rounded,
                color: AppTheme.secondary,
              ),
              _KpiCard(
                label: isEnglish ? 'Average ticket' : 'Ticket médio',
                value: _money(summary['average_ticket']),
                icon: Icons.show_chart_rounded,
                color: AppTheme.success,
              ),
              _KpiCard(
                label: isEnglish ? 'Active units' : 'Unidades ativas',
                value: '${_integer(summary['active_units'])}',
                icon: Icons.business_rounded,
                color: AppTheme.accent,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionGrid(
            columns: width >= 1000 ? 2 : 1,
            children: [
              _Panel(
                title: isEnglish ? 'Units' : 'Matriz e filiais',
                icon: Icons.location_city_rounded,
                child: units.isEmpty
                    ? _EmptyText(
                        isEnglish
                            ? 'No active units in this period.'
                            : 'Nenhuma unidade ativa no período.',
                      )
                    : Column(
                        children: units
                            .map(
                              (unit) => _UnitRow(
                                unit: unit,
                                money: _money,
                                isEnglish: isEnglish,
                              ),
                            )
                            .toList(),
                      ),
              ),
              _Panel(
                title: isEnglish ? 'Revenue by month' : 'Faturamento por mês',
                icon: Icons.insights_rounded,
                child: monthly.isEmpty
                    ? _EmptyText(
                        isEnglish
                            ? 'No reservations for the selected period.'
                            : 'Nenhuma reserva no período selecionado.',
                      )
                    : _MonthlyChart(
                        items: monthly,
                        money: _money,
                        isEnglish: isEnglish,
                      ),
              ),
              _Panel(
                title: isEnglish
                    ? 'Reservations by modality'
                    : 'Reservas por modalidade',
                icon: Icons.category_rounded,
                child: modalities.isEmpty
                    ? _EmptyText(
                        isEnglish
                            ? 'No modality data.'
                            : 'Sem dados de modalidade.',
                      )
                    : _BreakdownBars(
                        items: modalities,
                        money: _money,
                        isEnglish: isEnglish,
                      ),
              ),
              _Panel(
                title: isEnglish
                    ? 'Parking extra services'
                    : 'Serviços extras do estacionamento',
                icon: Icons.widgets_rounded,
                child: _AdditionalServices(
                  items: services,
                  money: _money,
                  isEnglish: isEnglish,
                ),
              ),
              _Panel(
                title: isEnglish ? 'Convenience products' : 'Conveniências',
                icon: Icons.shopping_bag_outlined,
                child: convenienceCategories.isEmpty
                    ? _EmptyText(
                        isEnglish
                            ? 'No convenience products registered.'
                            : 'Nenhum produto de conveniência cadastrado.',
                      )
                    : Column(
                        children: convenienceCategories
                            .map(
                              (item) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('${item['category'] ?? ''}'),
                                trailing: Text(
                                  '${item['products'] ?? 0} ${isEnglish ? 'products' : 'produtos'}',
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              _Panel(
                title: isEnglish ? 'Customer cities' : 'Cidades dos clientes',
                icon: Icons.map_rounded,
                child: cities.isEmpty
                    ? _EmptyText(
                        isEnglish
                            ? 'City data will appear as customers complete their profile.'
                            : 'Os dados aparecem quando os clientes informarem a cidade.',
                      )
                    : Column(
                        children: cities
                            .take(8)
                            .map((item) => _CityRow(item: item))
                            .toList(),
                      ),
              ),
              _Panel(
                title: isEnglish
                    ? 'Operation and coverage'
                    : 'Operação e cobertura',
                icon: Icons.groups_rounded,
                child: staffing.isEmpty
                    ? _EmptyText(
                        isEnglish
                            ? 'No shifts registered.'
                            : 'Nenhuma escala registrada.',
                      )
                    : Column(
                        children: staffing
                            .map(
                              (item) =>
                                  _StaffRow(item: item, isEnglish: isEnglish),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InsightsCard(data: data, isEnglish: isEnglish),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final bool isEnglish;
  final Map<String, dynamic> partner;
  const _IntroCard({required this.isEnglish, required this.partner});

  @override
  Widget build(BuildContext context) {
    final name = '${partner['name'] ?? ''}'.trim();
    return Card(
      color: AppTheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppTheme.accent,
              child: Icon(Icons.dashboard_rounded, color: AppTheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEnglish ? 'Business dashboard' : 'Dashboard da empresa',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name.isEmpty
                        ? (isEnglish
                              ? 'Consolidated operation view'
                              : 'Visão consolidada da operação')
                        : name,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final bool isEnglish;
  final String dateText;
  final DateTimeRange? period;
  final String? parkingId;
  final String serviceType;
  final List<Map<String, dynamic>> units;
  final ValueChanged<DateTimeRange?> onPeriodChanged;
  final ValueChanged<String?> onParkingChanged;
  final ValueChanged<String> onServiceChanged;

  const _FilterBar({
    required this.isEnglish,
    required this.dateText,
    required this.period,
    required this.parkingId,
    required this.serviceType,
    required this.units,
    required this.onPeriodChanged,
    required this.onParkingChanged,
    required this.onServiceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final unitItems = <DropdownMenuItem<String?>>[
      DropdownMenuItem(
        value: null,
        child: Text(isEnglish ? 'All units' : 'Todas as unidades'),
      ),
      ...units.map(
        (unit) => DropdownMenuItem<String?>(
          value: '${unit['id']}',
          child: Text(
            '${unit['name'] ?? 'Unidade'}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String?>(
                initialValue: parkingId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Unit' : 'Unidade',
                  prefixIcon: const Icon(Icons.business_outlined),
                ),
                items: unitItems,
                onChanged: onParkingChanged,
              ),
            ),
            SizedBox(
              width: 175,
              child: DropdownButtonFormField<String>(
                initialValue: serviceType,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Service' : 'Serviço',
                  prefixIcon: const Icon(Icons.tune_rounded),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text(
                      isEnglish ? 'All services' : 'Todos os serviços',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'parking',
                    child: Text(isEnglish ? 'Parking' : 'Estacionamento'),
                  ),
                  DropdownMenuItem(
                    value: 'guide',
                    child: Text(isEnglish ? 'Guide' : 'Guia turístico'),
                  ),
                  DropdownMenuItem(
                    value: 'hotel',
                    child: Text(isEnglish ? 'Hotels' : 'Hotéis'),
                  ),
                ],
                onChanged: (value) => onServiceChanged(value ?? 'all'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final value = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDateRange: period,
                );
                if (value != null) onPeriodChanged(value);
              },
              icon: const Icon(Icons.date_range_rounded),
              label: Text(dateText),
            ),
            if (period != null)
              TextButton(
                onPressed: () => onPeriodChanged(null),
                child: Text(isEnglish ? 'Clear' : 'Limpar'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionGrid extends StatelessWidget {
  final int columns;
  final List<Widget> children;
  const _SectionGrid({required this.columns, required this.children});
  @override
  Widget build(BuildContext context) {
    if (columns == 1) {
      return Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1) const SizedBox(height: 14),
          ],
        ],
      );
    }
    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.45,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Panel({required this.title, required this.icon, required this.child});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  final Map<String, dynamic> unit;
  final String Function(dynamic) money;
  final bool isEnglish;
  const _UnitRow({
    required this.unit,
    required this.money,
    required this.isEnglish,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(
          unit['unit_type'] == 'matriz'
              ? Icons.home_work_rounded
              : Icons.storefront_rounded,
          color: AppTheme.secondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${unit['name'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${unit['unit_type'] == 'matriz' ? (isEnglish ? 'Head office' : 'Matriz') : (isEnglish ? 'Branch' : 'Filial')} · ${unit['city'] ?? ''}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${unit['reservations'] ?? 0} ${isEnglish ? 'reservations' : 'reservas'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              money(unit['paid_revenue']),
              style: const TextStyle(color: AppTheme.success, fontSize: 12),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MonthlyChart extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String Function(dynamic) money;
  final bool isEnglish;
  const _MonthlyChart({
    required this.items,
    required this.money,
    required this.isEnglish,
  });
  @override
  Widget build(BuildContext context) {
    final values = items
        .map(
          (item) => item['revenue'] is num
              ? (item['revenue'] as num).toDouble()
              : 0.0,
        )
        .toList();
    final maxValue = values.fold<double>(
      0,
      (current, value) => math.max(current, value),
    );
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (values[i] > 0)
                      Text(
                        money(values[i]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      height: maxValue == 0
                          ? 3
                          : math.max(4, 88 * values[i] / maxValue),
                      decoration: BoxDecoration(
                        color: i.isEven ? AppTheme.secondary : AppTheme.accent,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${items[i]['month'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.textMuted,
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
}

class _BreakdownBars extends StatelessWidget {
  final Map<String, dynamic> items;
  final String Function(dynamic) money;
  final bool isEnglish;
  const _BreakdownBars({
    required this.items,
    required this.money,
    required this.isEnglish,
  });
  @override
  Widget build(BuildContext context) {
    final rows = items.entries.toList();
    final max = rows.fold<double>(
      0,
      (current, entry) => math.max(
        current,
        entry.value is Map
            ? (entry.value['reservations'] is num
                  ? (entry.value['reservations'] as num).toDouble()
                  : 0)
            : 0,
      ),
    );
    return Column(
      children: rows.map((entry) {
        final item = entry.value is Map
            ? Map<String, dynamic>.from(entry.value as Map)
            : <String, dynamic>{};
        final count = item['reservations'] is num
            ? (item['reservations'] as num).toDouble()
            : 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  _label(entry.key, isEnglish),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: max == 0 ? 0 : count / max,
                    color: AppTheme.secondary,
                    backgroundColor: AppTheme.softCyan,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${count.round()}'),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AdditionalServices extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String Function(dynamic) money;
  final bool isEnglish;
  const _AdditionalServices({
    required this.items,
    required this.money,
    required this.isEnglish,
  });
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyText(
        isEnglish
            ? 'No extra services registered for the units.'
            : 'Nenhum serviço extra cadastrado nas unidades.',
      );
    }
    return Column(
      children: items.map((item) {
        final reservations = item['reservations'] ?? 0;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.secondary,
            child: Icon(
              Icons.add_business_rounded,
              size: 17,
              color: Colors.white,
            ),
          ),
          title: Text('${item['name'] ?? item['code'] ?? ''}'),
          subtitle: Text(
            '${item['description'] ?? ''}\n$reservations ${isEnglish ? 'reservations' : 'reservas'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            money(item['revenue']),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      }).toList(),
    );
  }
}

class _CityRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _CityRow({required this.item});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: [
        const Icon(Icons.place_rounded, size: 18, color: AppTheme.secondary),
        const SizedBox(width: 7),
        Expanded(child: Text('${item['city'] ?? '—'}')),
        Text(
          '${item['reservations'] ?? 0}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _StaffRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isEnglish;
  const _StaffRow({required this.item, required this.isEnglish});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: const Icon(Icons.badge_outlined, color: AppTheme.secondary),
    title: Text('${item['parking_name'] ?? ''}'),
    subtitle: Text(
      '${item['operators'] ?? 0} ${isEnglish ? 'operators' : 'operadores'} · ${item['shifts'] ?? 0} ${isEnglish ? 'shifts' : 'turnos'}',
    ),
    trailing: (item['unassigned_shifts'] ?? 0) != 0
        ? Chip(
            label: Text(
              '${item['unassigned_shifts']} ${isEnglish ? 'open' : 'abertos'}',
            ),
          )
        : const Icon(Icons.check_circle, color: AppTheme.success),
  );
}

class _EmptyText extends StatelessWidget {
  final String text;
  const _EmptyText(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text, style: const TextStyle(color: AppTheme.textMuted)),
  );
}

class _InsightsCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isEnglish;
  const _InsightsCard({required this.data, required this.isEnglish});
  @override
  Widget build(BuildContext context) {
    final staffing =
        (data['staffing'] is List ? data['staffing'] as List : const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    final unassigned = staffing.fold<int>(
      0,
      (sum, item) =>
          sum +
          (item['unassigned_shifts'] is num
              ? (item['unassigned_shifts'] as num).toInt()
              : 0),
    );
    final text = unassigned > 0
        ? (isEnglish
              ? '$unassigned shift(s) still need an operator.'
              : '$unassigned turno(s) ainda precisam de operador.')
        : (isEnglish
              ? 'Your operation has no open shifts in this period.'
              : 'Sua operação não possui turnos sem operador no período.');
    return Card(
      color: AppTheme.softCyan,
      child: ListTile(
        leading: Icon(
          unassigned > 0
              ? Icons.warning_amber_rounded
              : Icons.lightbulb_outline_rounded,
          color: unassigned > 0 ? Colors.orange : AppTheme.secondary,
        ),
        title: Text(
          isEnglish ? 'Operational insight' : 'Insight operacional',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(text),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 42,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 10),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}

String _label(String key, bool isEnglish) => switch (key) {
  'hourly' => isEnglish ? 'Hourly' : 'Hora',
  'daily' => isEnglish ? 'Daily' : 'Diária',
  'weekly' => isEnglish ? 'Weekly' : 'Semanal',
  'monthly' => isEnglish ? 'Monthly' : 'Mensal',
  'parking' => isEnglish ? 'Parking' : 'Estacionamento',
  'guide' => isEnglish ? 'Guide' : 'Guia',
  'hotel' => isEnglish ? 'Hotel' : 'Hotel',
  _ => key,
};
