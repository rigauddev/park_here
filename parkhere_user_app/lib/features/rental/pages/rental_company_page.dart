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
    ]);
    return _RentalPageData(
      vehicles: results[0] as List<Map<String, dynamic>>,
      plans: results[1] as List<Map<String, dynamic>>,
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
              return ListView(children: [
                const SizedBox(height: 120),
                Center(child: Text('${snapshot.error}')),
              ]);
            }
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _hero(context, company, data),
                const SizedBox(height: 20),
                Text('Planos de contratação', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (data.plans.isEmpty) const Text('Planos em configuração.'),
                for (final plan in data.plans) _planCard(context, plan),
                const SizedBox(height: 20),
                Text('Veículos disponíveis', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (data.vehicles.isEmpty) const Text('Nenhum veículo disponível para o período informado.'),
                for (final vehicle in data.vehicles) _vehicleCard(context, vehicle),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, Map<String, dynamic> company, _RentalPageData data) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF102657), Color(0xFF169FC4)]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.directions_car_filled, color: Colors.white, size: 42),
          const SizedBox(height: 12),
          Text(company['name'] as String? ?? 'Locadora', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(company['address'] as String? ?? 'Endereço não informado', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: data.vehicles.isEmpty
                ? null
                : () => _showReservationDialog(data),
            icon: const Icon(Icons.calendar_month),
            label: const Text('Escolher período e reservar'),
          ),
        ]),
      ),
    );
  }

  Future<void> _showReservationDialog(_RentalPageData data) async {
    Map<String, dynamic>? vehicle = data.vehicles.first;
    Map<String, dynamic>? plan = data.plans.isEmpty ? null : data.plans.first;
    DateTimeRange? range;
    final companyId = widget.company['id'] as String;
    final token = (await LocalStorageService().getTokens())['access'];
    if (!mounted || token == null) return;
    await showDialog<void>(context: context, builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Nova reserva de locação'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: vehicle,
            decoration: const InputDecoration(labelText: 'Veículo'),
            items: [for (final item in data.vehicles) DropdownMenuItem(value: item, child: Text('${item['brand'] ?? ''} ${item['model'] ?? ''}'))],
            onChanged: (value) => setDialogState(() => vehicle = value),
          ),
          if (data.plans.isNotEmpty) DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: plan,
            decoration: const InputDecoration(labelText: 'Plano'),
            items: [for (final item in data.plans) DropdownMenuItem(value: item, child: Text(item['name'] as String? ?? 'Plano'))],
            onChanged: (value) => setDialogState(() => plan = value),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDateRangePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDateRange: range);
              if (picked != null) setDialogState(() => range = picked);
            },
            icon: const Icon(Icons.date_range),
            label: Text(range == null ? 'Escolher período' : '${_date(range!.start)} até ${_date(range!.end)}'),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: range == null || vehicle == null ? null : () async {
            try {
              await _service.reserve(companyId: companyId, vehicleId: vehicle!['id'] as String, planId: plan?['id'] as String?, start: range!.start, end: range!.end.add(const Duration(days: 1)), token: token);
              if (context.mounted) Navigator.pop(context);
              if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Reserva criada. O contrato será disponibilizado na próxima etapa.')));
            } catch (error) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível reservar: $error')));
            }
          }, child: const Text('Criar reserva')),
        ],
      ),
    ));
  }

  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';

  Widget _planCard(BuildContext context, Map<String, dynamic> plan) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.assignment_outlined)),
        title: Text(plan['name'] as String? ?? 'Plano'),
        subtitle: Text(plan['description'] as String? ?? 'Plano de locação'),
        trailing: Text('R\$ ${(plan['price_per_day'] as num?)?.toStringAsFixed(2) ?? '0,00'} / dia'),
      ),
    );
  }

  Widget _vehicleCard(BuildContext context, Map<String, dynamic> vehicle) {
    final photos = (vehicle['photo_urls'] as List<dynamic>?) ?? const [];
    return Card(
      child: ListTile(
        leading: photos.isNotEmpty
            ? Image.network(photos.first.toString(), width: 64, height: 52, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.directions_car_outlined, size: 36))
            : const Icon(Icons.directions_car_outlined, size: 36),
        title: Text('${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'),
        subtitle: Text('${vehicle['vehicle_type'] ?? 'car'} • ${vehicle['year'] ?? ''}'),
        trailing: Text('R\$ ${(vehicle['price_per_day'] as num?)?.toStringAsFixed(2) ?? '0,00'}'),
      ),
    );
  }
}

class _RentalPageData {
  final List<Map<String, dynamic>> vehicles;
  final List<Map<String, dynamic>> plans;

  const _RentalPageData({required this.vehicles, required this.plans});
}
