import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/reservation_enum.dart';
import '../models/reservation_model.dart';
import '../providers/reservation_provider.dart';
import 'resevation_details_page.dart';

class ReservationPage extends ConsumerWidget {
  const ReservationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(reservationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Historico de reservas")),
      body: reservationsAsync.when(
        data: (reservations) {
          if (reservations.isEmpty) {
            return const Center(child: Text("Nenhuma reserva encontrada."));
          }

          final ordered = [...reservations]
            ..sort((a, b) => b.checkinAt.compareTo(a.checkinAt));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ordered.length,
            itemBuilder: (context, index) {
              return _ReservationCard(reservation: ordered[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Erro: $e")),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final ReservationModel reservation;

  const _ReservationCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final status = _statusInfo(reservation.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.softCyan,
                  foregroundColor: AppTheme.primary,
                  child: const Icon(Icons.local_parking),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reservation.parkingName,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(reservation.checkinAt),
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(label: status.$1, color: status.$2),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _InfoPill(
                    label: "Plano",
                    value: reservation.plan.name.toUpperCase(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoPill(
                    label: "Valor",
                    value:
                        "R\$ ${(reservation.finalValue ?? reservation.estimatedValue).toStringAsFixed(2)}",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ReservationDetailsPage(reservation: reservation),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text("Detalhes"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _statusInfo(ReservationStatus status) {
    switch (status) {
      case ReservationStatus.open:
        return ("Aberta", Colors.orange);
      case ReservationStatus.finished:
        return ("Finalizada", AppTheme.success);
      case ReservationStatus.cancelled:
        return ("Cancelada", Colors.red);
      case ReservationStatus.expired:
        return ("Expirada", Colors.grey);
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return "$day/$month/${date.year} as $hour:$minute";
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;

  const _InfoPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.softCyan,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textMuted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
