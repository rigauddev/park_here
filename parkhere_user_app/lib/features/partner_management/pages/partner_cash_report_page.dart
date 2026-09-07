import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/partner_operations_provider.dart';

class PartnerCashReportPage extends ConsumerWidget {
  const PartnerCashReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservations = ref.watch(partnerReservationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Caixa e movimentações')),
      body: reservations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (items) {
          final today = DateTime.now();
          final daily = items.where((item) {
            final date = item.createdAt.toLocal();
            return date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
          }).toList();
          final received = daily
              .where((item) => item.paymentStatus == 'paid')
              .fold<double>(0, (sum, item) => sum + item.finalTotal);
          final active = daily
              .where((item) => item.status == 'checked_in')
              .length;
          final finalized = daily
              .where((item) => item.status == 'completed')
              .length;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(partnerReservationsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Visão básica incluída no plano atual'),
                    subtitle: Text(
                      'Entradas, saídas, reservas pagas e fechamento operacional. O Financeiro Pro é um complemento opcional.',
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        'Recebido hoje',
                        'R\$ ${received.toStringAsFixed(2)}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _Metric('Entradas', '$active')),
                    const SizedBox(width: 10),
                    Expanded(child: _Metric('Saídas', '$finalized')),
                  ],
                ),
                const SizedBox(height: 16),
                for (final item in daily)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        item.status == 'completed' ? Icons.logout : Icons.login,
                      ),
                      title: Text(item.vehiclePlate ?? 'Veículo sem placa'),
                      subtitle: Text('${item.status} • ${item.paymentStatus}'),
                      trailing: Text(
                        'R\$ ${item.finalTotal.toStringAsFixed(2)}',
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric(this.label, this.value);
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
