import 'package:flutter/material.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/local_storage_service.dart';

class ParkingDashboardPage extends StatefulWidget {
  const ParkingDashboardPage({super.key});

  @override
  State<ParkingDashboardPage> createState() => _ParkingDashboardPageState();
}

class _ParkingDashboardPageState extends State<ParkingDashboardPage> {
  DateTimeRange? _period;
  String _plan = 'Todos';
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final token = (await LocalStorageService().getTokens())['access'];
    if (token == null || token.isEmpty) return const [];
    final data = await ApiService().getAuthorized(
      '/partners/reservations',
      token,
    );
    return data.cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard do estacionamento'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _future = _load()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          final isPt = Localizations.localeOf(context).languageCode != 'en';
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text('Erro: ${snapshot.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final reservations = snapshot.data!.where(_matches).toList();
          final received = reservations.fold<double>(
            0,
            (sum, item) =>
                sum +
                (item['payment_status'] == 'paid'
                    ? ((item['final_total'] as num?)?.toDouble() ?? 0)
                    : 0),
          );
          final average = reservations.isEmpty
              ? 0
              : received / reservations.length;
          final completed = reservations
              .where((item) => item['status'] == 'completed')
              .length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      initialValue: _plan,
                      decoration: InputDecoration(
                        labelText: isPt
                            ? 'Tipo de reserva / vaga'
                            : 'Reservation / spot type',
                      ),
                      items: ['Todos', 'hourly', 'daily', 'weekly', 'monthly']
                          .map((value) => DropdownMenuItem(
                              value: value, child: Text(value)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _plan = value ?? 'Todos'),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDateRange: _period,
                      );
                      if (range != null) setState(() => _period = range);
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(_period == null
                        ? (isPt ? 'Período' : 'Period')
                        : '${_period!.start.day}/${_period!.start.month} – ${_period!.end.day}/${_period!.end.month}'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(
                    isPt ? 'Reservas' : 'Reservations',
                    '${reservations.length}',
                    Icons.event_available,
                  ),
                  _MetricCard(
                    isPt ? 'Recebido no período' : 'Received in period',
                    "R\$ ${received.toStringAsFixed(2)}",
                    Icons.payments,
                  ),
                  _MetricCard(
                    isPt ? 'Ticket médio' : 'Average ticket',
                    "R\$ ${average.toStringAsFixed(2)}",
                    Icons.analytics,
                  ),
                  _MetricCard(isPt ? 'Concluídas' : 'Completed', '$completed', Icons.check_circle),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                isPt ? 'Reservas recentes' : 'Recent reservations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final reservation in reservations.take(20))
                ListTile(
                  leading: const Icon(Icons.local_parking_outlined),
                  title: Text(
                    "${reservation['pricing_plan'] ?? 'Reserva'} · ${reservation['status'] ?? ''}",
                  ),
                  subtitle: Text(
                    "R\$ ${((reservation['final_total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}",
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _matches(Map<String, dynamic> item) {
    if (_plan != 'Todos' && item['pricing_plan'] != _plan) return false;
    final raw = DateTime.tryParse('${item['created_at'] ?? ''}');
    if (raw == null || _period == null) return true;
    final date = raw.toLocal();
    return !date.isBefore(_period!.start) &&
        !date.isAfter(_period!.end.add(const Duration(days: 1)));
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
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
}
