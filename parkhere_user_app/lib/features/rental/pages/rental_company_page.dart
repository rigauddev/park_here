import 'package:flutter/material.dart';

import '../../../core/services/local_storage_service.dart';
import '../services/rental_service.dart';

class RentalCompanyPage extends StatefulWidget {
  final Map<String, dynamic> company;

  const RentalCompanyPage({super.key, required this.company});

  @override
  State<RentalCompanyPage> createState() => _RentalCompanyPageState();
}

class _RentalCompanyPageState extends State<RentalCompanyPage> {
  final _service = RentalService();
  late Future<_RentalPageData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_RentalPageData> _load() async {
    final token = (await LocalStorageService().getTokens())['access'];
    if (token == null) throw Exception('Sessão expirada.');
    final companyId = widget.company['id'] as String;
    final results = await Future.wait([
      _service.vehicles(companyId, token),
      _service.plans(companyId, token),
      _service.groups(companyId, token),
    ]);
    return _RentalPageData(
      vehicles: results[0] as List<Map<String, dynamic>>,
      plans: results[1] as List<Map<String, dynamic>>,
      groups: results[2] as List<Map<String, dynamic>>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final company = widget.company;
    return Scaffold(
      appBar: AppBar(title: Text(company['name'] as String? ?? 'Locadora')),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _future = _load()),
        child: FutureBuilder<_RentalPageData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text('${snapshot.error}')),
                ],
              );
            }
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _hero(context, company, data),
                const SizedBox(height: 20),
                Text(
                  'Planos de contratação',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (data.plans.isEmpty) const Text('Planos em configuração.'),
                for (final plan in data.plans) _planCard(context, plan),
                const SizedBox(height: 20),
                Text(
                  'Veículos disponíveis',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (data.vehicles.isEmpty)
                  const Text(
                    'Nenhum veículo disponível para o período informado.',
                  ),
                for (final group in data.groups)
                  _groupCard(context, group, data),
                if (data.groups.isEmpty)
                  for (final vehicle in data.vehicles)
                    _vehicleCard(context, vehicle),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hero(
    BuildContext context,
    Map<String, dynamic> company,
    _RentalPageData data,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF102657), Color(0xFF169FC4)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.directions_car_filled,
              color: Colors.white,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              company['name'] as String? ?? 'Locadora',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              company['address'] as String? ?? 'Endereço não informado',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: data.vehicles.isEmpty
                  ? null
                  : () => _showReservationDialog(data),
              icon: const Icon(Icons.calendar_month),
              label: const Text('Escolher período e reservar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReservationDialog(
    _RentalPageData data, {
    Map<String, dynamic>? initialVehicle,
  }) async {
    Map<String, dynamic>? vehicle = initialVehicle ?? data.vehicles.first;
    Map<String, dynamic>? plan = data.plans.isEmpty ? null : data.plans.first;
    DateTimeRange? range;
    TimeOfDay? pickupTime;
    TimeOfDay? returnTime;
    final companyId = widget.company['id'] as String;
    final token = (await LocalStorageService().getTokens())['access'];
    if (!mounted || token == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nova reserva de locação'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: vehicle,
                  decoration: const InputDecoration(labelText: 'Veículo'),
                  items: [
                    for (final item in data.vehicles)
                      DropdownMenuItem(
                        value: item,
                        child: Text(
                          '${item['brand'] ?? ''} ${item['model'] ?? ''}',
                        ),
                      ),
                  ],
                  onChanged: (value) => setDialogState(() => vehicle = value),
                ),
                if (data.plans.isNotEmpty)
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: plan,
                    decoration: const InputDecoration(labelText: 'Plano'),
                    items: [
                      for (final item in data.plans)
                        DropdownMenuItem(
                          value: item,
                          child: Text(item['name'] as String? ?? 'Plano'),
                        ),
                    ],
                    onChanged: (value) => setDialogState(() => plan = value),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDateRange: range,
                    );
                    if (picked != null) {
                      final pickup = await showTimePicker(
                        context: context,
                        initialTime: pickupTime ?? TimeOfDay.now(),
                        helpText: 'Horário de retirada',
                      );
                      if (pickup == null || !context.mounted) return;
                      final returned = await showTimePicker(
                        context: context,
                        initialTime: returnTime ?? pickup,
                        helpText: 'Horário de devolução',
                      );
                      if (returned != null)
                        setDialogState(() {
                          range = picked;
                          pickupTime = pickup;
                          returnTime = returned;
                        });
                    }
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    range == null
                        ? 'Escolher data e horário'
                        : '${_dateTime(range!.start, pickupTime)} até ${_dateTime(range!.end, returnTime)}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed:
                  range == null ||
                      vehicle == null ||
                      pickupTime == null ||
                      returnTime == null
                  ? null
                  : () async {
                      try {
                        final start = DateTime(
                          range!.start.year,
                          range!.start.month,
                          range!.start.day,
                          pickupTime!.hour,
                          pickupTime!.minute,
                        );
                        final end = DateTime(
                          range!.end.year,
                          range!.end.month,
                          range!.end.day,
                          returnTime!.hour,
                          returnTime!.minute,
                        );
                        if (!end.isAfter(start)) {
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'A devolução deve ser posterior à retirada.',
                                ),
                              ),
                            );
                          return;
                        }
                        await _service.reserve(
                          companyId: companyId,
                          vehicleId: vehicle!['id'] as String,
                          planId: plan?['id'] as String?,
                          start: start,
                          end: end,
                          token: token,
                        );
                        if (context.mounted) Navigator.pop(context);
                        if (mounted)
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Reserva criada. O contrato será disponibilizado na próxima etapa.',
                              ),
                            ),
                          );
                      } catch (error) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Não foi possível reservar: $error',
                              ),
                            ),
                          );
                      }
                    },
              child: const Text('Criar reserva'),
            ),
          ],
        ),
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';

  String _dateTime(DateTime date, TimeOfDay? time) =>
      '${_date(date)} ${time?.format(context) ?? '--:--'}';

  Widget _planCard(BuildContext context, Map<String, dynamic> plan) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.assignment_outlined)),
        title: Text(plan['name'] as String? ?? 'Plano'),
        subtitle: Text(plan['description'] as String? ?? 'Plano de locação'),
        trailing: Text(
          'R\$ ${(plan['price_per_day'] as num?)?.toStringAsFixed(2) ?? '0,00'} / dia',
        ),
      ),
    );
  }

  Widget _vehicleCard(BuildContext context, Map<String, dynamic> vehicle) {
    final photos = (vehicle['photo_urls'] as List<dynamic>?) ?? const [];
    return Card(
      child: ListTile(
        leading: photos.isNotEmpty
            ? Image.network(
                photos.first.toString(),
                width: 64,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.directions_car_outlined, size: 36),
              )
            : const Icon(Icons.directions_car_outlined, size: 36),
        title: Text('${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'),
        subtitle: Text(
          '${vehicle['vehicle_type'] ?? 'car'} • ${vehicle['year'] ?? ''}',
        ),
        trailing: Text(
          'R\$ ${(vehicle['price_per_day'] as num?)?.toStringAsFixed(2) ?? '0,00'}',
        ),
      ),
    );
  }

  Widget _groupCard(
    BuildContext context,
    Map<String, dynamic> group,
    _RentalPageData data,
  ) {
    final groupId = group['id']?.toString();
    final vehicles = data.vehicles
        .where((item) => item['group_id']?.toString() == groupId)
        .toList();
    if (vehicles.isEmpty) return const SizedBox.shrink();
    final first = vehicles.first;
    final photos = (first['photo_urls'] as List<dynamic>?) ?? const [];
    final price =
        (group['suggested_price_per_day'] ?? first['price_per_day']) as num?;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              width: double.infinity,
              child: photos.isEmpty
                  ? const Icon(Icons.directions_car_filled, size: 72)
                  : Image.network(
                      photos.first.toString(),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.directions_car_filled, size: 72),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              group['name']?.toString() ?? 'Grupo de veículos',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              vehicles
                  .map((v) => '${v['brand'] ?? ''} ${v['model'] ?? ''}'.trim())
                  .join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if ((group['description']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                group['description'].toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'A partir de R\$ ${price?.toStringAsFixed(2) ?? '0,00'} / dia',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        _showReservationDialog(data, initialVehicle: first),
                    child: const Text('Reservar agora'),
                  ),
                ),
                TextButton(
                  onPressed: () => _showGroupDetails(context, group, first),
                  child: const Text('Mostrar detalhes'),
                ),
              ],
            ),
            const Text(
              '* Modelo sujeito à disponibilidade da agência.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupDetails(
    BuildContext context,
    Map<String, dynamic> group,
    Map<String, dynamic> vehicle,
  ) {
    final specs =
        vehicle['specifications'] as Map<String, dynamic>? ?? const {};
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(group['name']?.toString() ?? 'Detalhes do grupo'),
        content: SingleChildScrollView(
          child: Text(
            [
              group['description']?.toString() ?? '',
              if (specs.isNotEmpty)
                specs.entries
                    .map((entry) => '${entry.key}: ${entry.value}')
                    .join('\n'),
            ].where((item) => item.trim().isNotEmpty).join('\n\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

class _RentalPageData {
  final List<Map<String, dynamic>> vehicles;
  final List<Map<String, dynamic>> plans;
  final List<Map<String, dynamic>> groups;

  const _RentalPageData({
    required this.vehicles,
    required this.plans,
    this.groups = const [],
  });
}
