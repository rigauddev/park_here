import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../checkin_checkout/models/pre_checkin_model.dart';
import '../../checkin_checkout/pages/checkin_page.dart';
import '../../parking_search/models/parking_model.dart';
import '../../parking_search/models/parking_pricing.dart';
import '../../parking_search/models/payment_plan_enum.dart';
import '../models/reservation_enum.dart';
import '../models/reservation_model.dart';
import '../providers/pre_reservation_provider.dart';
import '../providers/reservation_provider.dart';
import 'resevation_details_page.dart';

class ReservationPage extends ConsumerStatefulWidget {
  const ReservationPage({super.key});

  @override
  ConsumerState<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends ConsumerState<ReservationPage>
    with SingleTickerProviderStateMixin {
  String serviceFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(reservationsProvider);
    final preReservationAsync = ref.watch(preReservationProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Reservas e serviços"),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Reservas'),
              Tab(text: 'Serviços'),
            ],
          ),
        ),
        body: reservationsAsync.when(
          data: (reservations) {
            final preReservation = preReservationAsync.when(
              data: (value) => value,
              loading: () => null,
              error: (_, __) => null,
            );
            final allReservations = [
              if (preReservation != null)
                ReservationModel(
                  id: preReservation.id,
                  parkingName: preReservation.parkingName,
                  plan: PlanType.hourly,
                  status: preReservation.active && !preReservation.isExpired
                      ? ReservationStatus.open
                      : ReservationStatus.expired,
                  checkinAt: preReservation.createdAt,
                  estimatedValue: 0,
                  carWash: false,
                  tourGuide: false,
                  transport: false,
                  firstHourPrice: 0,
                  additionalHourPrice: 0,
                  checkinTime: preReservation.createdAt,
                  hasUnpaidServices: false,
                  unpaidServicesValue: 0,
                  validUntil: preReservation.expiresAt,
                  preCheckin: PreCheckinModel(
                    parking: ParkingModel(
                      id: preReservation.parkingId,
                      name: preReservation.parkingName,
                      city: 'Valença',
                      lat: 0,
                      lng: 0,
                      rating: 0,
                      availableSpots: 0,
                      pricing: ParkingPricing(
                        firstHourPrice: 0,
                        additionalHourPrice: 0,
                        dailyPrice: 0,
                        monthlyPrice: 0,
                      ),
                      hasCarWash: false,
                      hasTourGuide: false,
                      hasTransportService: false,
                      hasCoveredArea: false,
                      hasVipSpots: false,
                      carWashPrice: 0,
                      tourGuidePrice: 0,
                      transportPrice: 0,
                    ),
                    plan: PlanType.hourly,
                    carWash: false,
                    tourGuide: false,
                    transport: false,
                    total: 0,
                    userLocationLat: 0,
                    userLocationLng: 0,
                  ),
                ),
              ...reservations,
            ];

            if (allReservations.isEmpty) {
              return const Center(child: Text("Nenhuma reserva encontrada."));
            }

            final ordered = [...allReservations]
              ..sort((a, b) => b.checkinAt.compareTo(a.checkinAt));

            final contractedServices = _contractedServices(ordered)
                .where(
                  (service) =>
                      serviceFilter == 'all' || service.code == serviceFilter,
                )
                .toList();

            return TabBarView(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ordered.length,
                  itemBuilder: (context, index) {
                    return _ReservationCard(reservation: ordered[index]);
                  },
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: serviceFilter,
                      decoration: const InputDecoration(
                        labelText: 'Filtrar por tipo de serviço',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Todos')),
                        DropdownMenuItem(
                          value: 'parking',
                          child: Text('Estacionamento'),
                        ),
                        DropdownMenuItem(
                          value: 'car_wash',
                          child: Text('Lava jato'),
                        ),
                        DropdownMenuItem(
                          value: 'tour_guide',
                          child: Text('Passeios turísticos'),
                        ),
                        DropdownMenuItem(
                          value: 'transport',
                          child: Text('Transporte'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => serviceFilter = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    if (contractedServices.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Text('Nenhum serviço contratado.'),
                        ),
                      )
                    else
                      for (final service in contractedServices)
                        _ContractedServiceCard(service: service),
                  ],
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text("Erro: $e")),
        ),
      ),
    );
  }

  List<_ContractedService> _contractedServices(
    List<ReservationModel> reservations,
  ) {
    final services = <_ContractedService>[];

    for (final reservation in reservations) {
      final amount = reservation.finalValue ?? reservation.estimatedValue;
      services.add(
        _ContractedService(
          code: 'parking',
          name: 'Estacionamento',
          reservation: reservation,
          amount: amount,
        ),
      );

      if (reservation.carWash) {
        services.add(
          _ContractedService(
            code: 'car_wash',
            name: 'Lava jato',
            reservation: reservation,
            amount: 0,
          ),
        );
      }
      if (reservation.tourGuide) {
        services.add(
          _ContractedService(
            code: 'tour_guide',
            name: 'Passeio turístico',
            reservation: reservation,
            amount: 0,
          ),
        );
      }
      if (reservation.transport) {
        services.add(
          _ContractedService(
            code: 'transport',
            name: 'Transporte',
            reservation: reservation,
            amount: 0,
          ),
        );
      }
    }

    return services;
  }
}

class _ContractedService {
  final String code;
  final String name;
  final ReservationModel reservation;
  final double amount;

  const _ContractedService({
    required this.code,
    required this.name,
    required this.reservation,
    required this.amount,
  });
}

class _ContractedServiceCard extends StatelessWidget {
  final _ContractedService service;

  const _ContractedServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.softCyan,
          foregroundColor: AppTheme.primary,
          child: Icon(_iconFor(service.code)),
        ),
        title: Text(service.name),
        subtitle: Text(service.reservation.parkingName),
        trailing: service.amount > 0
            ? Text(
                'R\$ ${service.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              )
            : const Text('Incluído'),
      ),
    );
  }

  IconData _iconFor(String code) {
    return switch (code) {
      'car_wash' => Icons.local_car_wash,
      'tour_guide' => Icons.tour,
      'transport' => Icons.local_taxi,
      _ => Icons.local_parking,
    };
  }
}

class _ReservationCard extends StatelessWidget {
  final ReservationModel reservation;

  const _ReservationCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final status = _statusInfo(reservation.status);
    final remaining = reservation.validUntil.difference(DateTime.now());
    final remainingText = remaining.isNegative
        ? 'Expirado'
        : 'Expira em ${_formatDuration(remaining)}';

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
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: remaining.isNegative
                    ? Colors.red.shade50
                    : AppTheme.softCyan,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    remaining.isNegative
                        ? Icons.timer_off_outlined
                        : Icons.timer_outlined,
                    color: remaining.isNegative ? Colors.red : AppTheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    remainingText,
                    style: TextStyle(
                      color: remaining.isNegative
                          ? Colors.red
                          : AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(
                  label: 'Vagas disponíveis',
                  value: '${reservation.preCheckin.parking.availableSpots}',
                ),
                if (reservation.tourGuide)
                  const _InfoPill(label: 'Guia', value: 'Indicado'),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  if (reservation.status == ReservationStatus.open &&
                      reservation.checkedIn)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CheckinPage(preCheckin: reservation.preCheckin),
                          ),
                        );
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Check-in'),
                    ),
                  IconButton(
                    tooltip: 'Agendar reserva / Schedule reservation',
                    onPressed: () => _showScheduleDialog(context),
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                  TextButton.icon(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agendar reserva / Schedule'),
        content: const Text(
          'Escolha a data e informe o horário de chegada. O pagamento antecipado de 50% será habilitado na próxima etapa do Mercado Pago.\n\nChoose the date and arrival time. The 50% prepayment will be enabled in the next Mercado Pago step.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar / Close'),
          ),
        ],
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
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
