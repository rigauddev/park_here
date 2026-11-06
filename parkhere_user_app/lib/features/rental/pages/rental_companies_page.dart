import 'package:flutter/material.dart';
import '../../../core/services/local_storage_service.dart';
import '../services/rental_service.dart';

class RentalCompaniesPage extends StatefulWidget {
  const RentalCompaniesPage({super.key});
  @override
  State<RentalCompaniesPage> createState() => _RentalCompaniesPageState();
}

class _RentalCompaniesPageState extends State<RentalCompaniesPage> {
  final _service = RentalService();
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final token = (await LocalStorageService().getTokens())['access'];
    if (token == null) throw Exception('Sessão expirada.');
    return _service.companies(token);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Locação de veículos')),
    body: RefreshIndicator(
      onRefresh: () async => setState(() => _future = _load()),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text('${snapshot.error}'));
          final companies = snapshot.data ?? const [];
          if (companies.isEmpty)
            return const Center(child: Text('Nenhuma locadora disponível.'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: companies.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final company = companies[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.directions_car_filled),
                  ),
                  title: Text(company['name'] as String? ?? 'Locadora'),
                  subtitle: Text(
                    company['address'] as String? ?? 'Endereço não informado',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showVehicles(company),
                ),
              );
            },
          );
        },
      ),
    ),
  );

  Future<void> _showVehicles(Map<String, dynamic> company) async {
    final token = (await LocalStorageService().getTokens())['access'];
    if (token == null || !mounted) return;
    final vehicles = await _service.vehicles(company['id'] as String, token);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              company['name'] as String? ?? 'Veículos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final vehicle in vehicles)
              ListTile(
                leading: const Icon(Icons.directions_car_outlined),
                title: Text('${vehicle['brand']} ${vehicle['model']}'),
                subtitle: Text(
                  'R\$ ${(vehicle['price_per_day'] as num?)?.toStringAsFixed(2) ?? '0,00'} / dia',
                ),
              ),
            if (vehicles.isEmpty)
              const Text('Nenhum veículo disponível para o período atual.'),
          ],
        ),
      ),
    );
  }
}
