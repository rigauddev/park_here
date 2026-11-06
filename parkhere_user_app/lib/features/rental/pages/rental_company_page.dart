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
                _hero(context, company),
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

  Widget _hero(BuildContext context, Map<String, dynamic> company) {
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
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Selecione um veículo e um plano para iniciar a reserva.')),
            ),
            icon: const Icon(Icons.calendar_month),
            label: const Text('Escolher período e reservar'),
          ),
        ]),
      ),
    );
  }

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
