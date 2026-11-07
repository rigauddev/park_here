import 'package:flutter/material.dart';

import '../../../core/services/local_storage_service.dart';
import '../services/rental_service.dart';

/// Lista operacional das reservas da locadora, separada da gestão da frota.
/// A separação evita misturar manutenção/cadastro de veículos com atendimento.
class RentalReservationsPage extends StatefulWidget {
  const RentalReservationsPage({super.key});

  @override
  State<RentalReservationsPage> createState() => _RentalReservationsPageState();
}

class _RentalReservationsPageState extends State<RentalReservationsPage> {
  final _service = RentalService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final token = (await LocalStorageService().getTokens())['access'];
    if (token == null || token.isEmpty) throw Exception('Sessão expirada.');
    return _service.reservations(token);
  }

  String _text(Object? value) =>
      value?.toString().trim().isNotEmpty == true ? value.toString() : '—';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservas da locadora'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () => setState(() => _future = _load()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar as reservas.\n${snapshot.error}',
                ),
              ),
            );
          }
          final reservations = snapshot.data ?? const [];
          if (reservations.isEmpty) {
            return const Center(
              child: Text('Nenhuma reserva de locação encontrada.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reservations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final reservation = reservations[index];
                final status = _text(reservation['status']);
                final vehicle = reservation['vehicle'] as Map<String, dynamic>?;
                final vehicleName = vehicle == null
                    ? _text(reservation['vehicle_id'])
                    : '${_text(vehicle['brand'])} ${_text(vehicle['model'])}'
                          .trim();
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.directions_car_outlined),
                    ),
                    title: Text('Reserva ${_text(reservation['id'])}'),
                    subtitle: Text(
                      'Veículo: $vehicleName\n'
                      'Período: ${_text(reservation['start_at'])} → ${_text(reservation['end_at'])}\n'
                      'Total: R\$ ${_text(reservation['final_total'] ?? reservation['total_amount'])}',
                    ),
                    isThreeLine: true,
                    trailing: Chip(label: Text(status)),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
