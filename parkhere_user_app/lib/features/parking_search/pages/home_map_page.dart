import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/routes/route_service.dart';
import '../../account/pages/vehicles_page.dart';
import '../../account/providers/account_provider.dart';
import '../../checkin_checkout/models/pre_checkin_model.dart';
import '../../checkin_checkout/pages/route_preview_page.dart';
import '../../reservation/providers/pre_reservation_provider.dart';
import '../models/parking_model.dart';
import '../models/payment_plan_enum.dart';
import '../providers/filter_provider.dart';
import '../providers/parking_provider.dart';
import '../providers/search_provider.dart';
import '../providers/selected_plan_provider.dart';
import '../providers/selected_services_provider.dart';
import '../widgets/filter_sheet.dart';

class HomeMapPage extends ConsumerStatefulWidget {
  const HomeMapPage({super.key});

  @override
  ConsumerState<HomeMapPage> createState() => _HomeMapPageState();
}

class _HomeMapPageState extends ConsumerState<HomeMapPage> {
  void openParkingDetails(
    BuildContext context,
    ParkingModel parking,
    LatLng position,
  ) {
    // Reset plano e serviços ao abrir
    ref.read(selectedPlanProvider.notifier).state = null;
    ref.read(selectedServicesProvider.notifier).state = SelectedServices();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Consumer(
          builder: (context, ref, child) {
            final plan = ref.watch(selectedPlanProvider);
            final selected = ref.watch(selectedServicesProvider);

            // ===============================
            // ✅ ETAPA 1 — Escolher Plano
            // ===============================
            if (plan == null) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Barra Uber
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    Text(
                      parking.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF102657),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      "Escolha seu plano:",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    // ✅ Botão Hora
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text("Avulso por hora"),
                      subtitle: Text(
                        "Primeira hora: R\$ ${parking.pricing.firstHourPrice}",
                      ),
                      onTap: () {
                        ref.read(selectedPlanProvider.notifier).state =
                            PlanType.hourly;
                      },
                    ),

                    // ✅ Botão Diária
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text("Diária"),
                      subtitle: Text(
                        "Valor: R\$ ${parking.pricing.dailyPrice}",
                      ),
                      onTap: () {
                        ref.read(selectedPlanProvider.notifier).state =
                            PlanType.daily;
                      },
                    ),

                    // ✅ Botão Mensal
                    ListTile(
                      leading: const Icon(Icons.calendar_month),
                      title: const Text("Mensal"),
                      subtitle: Text(
                        "Valor: R\$ ${parking.pricing.monthlyPrice}",
                      ),
                      onTap: () {
                        ref.read(selectedPlanProvider.notifier).state =
                            PlanType.monthly;
                      },
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              );
            }

            // ===============================
            // ✅ ETAPA 2 — Detalhes do Plano
            // ===============================

            double total = 0;

            switch (plan) {
              case PlanType.hourly:
                total = parking.pricing.firstHourPrice;
                break;
              case PlanType.daily:
                total = parking.pricing.dailyPrice;
                break;
              case PlanType.monthly:
                total = parking.pricing.monthlyPrice;
                break;
            }

            // Extras
            if (selected.carWash) total += parking.carWashPrice;
            if (selected.tourGuide) total += parking.tourGuidePrice;
            if (selected.transport) total += parking.transportPrice;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barra Uber
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  TextButton.icon(
                    onPressed: () {
                      ref.read(selectedPlanProvider.notifier).state = null;
                    },
                    label: const Text(
                      "Alterar plano",
                      style: TextStyle(
                        color: Color(0xFF169FC4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF169FC4),
                    ),
                  ),

                  // Nome + Plano escolhido
                  Text(
                    parking.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF102657),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "Plano selecionado: ${plan.name.toUpperCase()}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF169FC4),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Info de cobrança
                  if (plan == PlanType.hourly)
                    Text(
                      "⏱ Primeira hora: R\$ ${parking.pricing.firstHourPrice}\n"
                      "➕ Hora adicional: R\$ ${parking.pricing.additionalHourPrice}",
                    ),

                  if (plan == PlanType.daily)
                    Text("📅 Diária: R\$ ${parking.pricing.dailyPrice}"),

                  if (plan == PlanType.monthly)
                    Text("📆 Mensal: R\$ ${parking.pricing.monthlyPrice}"),

                  const SizedBox(height: 20),

                  // Serviços adicionais
                  const Text(
                    "Serviços adicionais:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  if (parking.hasCarWash)
                    CheckboxListTile(
                      title: Text("Lavagem (+R\$ ${parking.carWashPrice})"),
                      value: selected.carWash,
                      onChanged: (v) {
                        ref.read(selectedServicesProvider.notifier).state =
                            selected.copyWith(carWash: v);
                      },
                    ),

                  if (parking.hasTourGuide)
                    CheckboxListTile(
                      title: Text(
                        "Guia turístico (+R\$ ${parking.tourGuidePrice})",
                      ),
                      value: selected.tourGuide,
                      onChanged: (v) {
                        ref.read(selectedServicesProvider.notifier).state =
                            selected.copyWith(tourGuide: v);
                      },
                    ),

                  if (parking.hasTransportService)
                    CheckboxListTile(
                      title: Text(
                        "Transporte (+R\$ ${parking.transportPrice})",
                      ),
                      value: selected.transport,
                      onChanged: (v) {
                        ref.read(selectedServicesProvider.notifier).state =
                            selected.copyWith(transport: v);
                      },
                    ),

                  const SizedBox(height: 15),

                  // Total estimado
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAFBFF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total estimado:"),
                        Text(
                          "R\$ $total",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF169FC4),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Botão continuar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF169FC4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () {
                        _startRoute(
                          parking: parking,
                          plan: plan,
                          selected: selected,
                          total: total,
                          userLocationLat: position.latitude,
                          userLocationLng: position.longitude,
                        );
                      },
                      child: const Text(
                        "Reservar e bloquear vaga",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lista de parques carregada do provider
    final parkingState = ref.watch(parkingProvider);

    // Texto digitado no campo de busca
    final searchQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      body: parkingState.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (err, stack) => Center(child: Text("Erro ao carregar: $err")),

        data: (parkings) {
          // ✅ Filtrar por nome
          // final filteredParkings = parkings.where((p) {
          //   return p.name.toLowerCase().contains(
          //         searchQuery.toLowerCase(),
          //       );
          // }).toList();

          final filter = ref.watch(filterProvider);

          final filteredParkings = parkings.where((p) {
            // if (filter.covered && !p.hasCoveredArea) return false;
            // if (filter.vip && !p.hasVipSpots) return false;
            if (filter.carWash && !p.hasCarWash) return false;
            if (filter.tourGuide && !p.hasTourGuide) return false;
            if (filter.transport && !p.hasTransportService) return false;

            return p.name.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();

          // ✅ ordenar por melhor avaliado
          filteredParkings.sort((a, b) => b.rating.compareTo(a.rating));

          return Stack(
            children: [
              // ✅ MAPA FULLSCREEN
              FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(-12.9708, -38.5123),
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png",
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'br.com.rptech.parkhere_user_app',
                  ),

                  MarkerLayer(
                    markers: filteredParkings.map((parking) {
                      return Marker(
                        point: LatLng(parking.lat, parking.lng),
                        child: GestureDetector(
                          onTap: () => openParkingDetails(
                            context,
                            parking,
                            LatLng(parking.lat, parking.lng),
                          ),
                          child: const Icon(
                            Icons.local_parking,
                            size: 42,
                            color: Color(0xFF169FC4),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // ✅ CAMPO DE BUSCA + FILTRO FIXO NO TOPO
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Buscar estacionamento...",
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      ref
                                              .read(
                                                searchQueryProvider.notifier,
                                              )
                                              .state =
                                          "";
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            ref.read(searchQueryProvider.notifier).state =
                                value;
                          },
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Botão filtro
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 6,
                              color: Colors.black.withValues(alpha: 0.05),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.filter_list,
                            color: Color(0xFF169FC4),
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                              ),
                              builder: (_) => const ParkingFilterSheet(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ✅ BOTTOMSHEET DESLIZANTE (ESTILO UBER)
              DraggableScrollableSheet(
                initialChildSize: 0.25, // começa pequeno
                minChildSize: 0.18,
                maxChildSize: 0.75, // pode expandir bastante
                builder: (context, scrollController) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(blurRadius: 10, color: Colors.black26),
                      ],
                    ),

                    child: Column(
                      children: [
                        // ✅ Barra superior
                        Container(
                          width: 50,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),

                        const Text(
                          "Estacionamentos próximos",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF102657),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ✅ LISTA DE CARDS
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: filteredParkings.length,
                            itemBuilder: (context, index) {
                              final parking = filteredParkings[index];

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // ✅ Nome + Preço
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              parking.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            "R\$ ${parking.pricing.firstHourPrice}/h",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF169FC4),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 4),

                                      // ✅ Vagas + Avaliação
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Vagas: ${parking.availableSpots}",
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            "⭐ ${parking.rating}",
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 10),

                                      // ✅ Chips de serviços
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          if (parking.hasCarWash)
                                            _serviceChip(
                                              "Lavagem",
                                              Icons.local_car_wash,
                                            ),

                                          if (parking.hasTourGuide)
                                            _serviceChip("Guia", Icons.map),

                                          if (parking.hasTransportService)
                                            _serviceChip(
                                              "Transporte",
                                              Icons.directions_car,
                                            ),
                                        ],
                                      ),

                                      const SizedBox(height: 10),

                                      // ✅ Botão de detalhes
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () => openParkingDetails(
                                            context,
                                            parking,
                                            LatLng(parking.lat, parking.lng),
                                          ),
                                          child: const Text(
                                            "Ver detalhes",
                                            style: TextStyle(
                                              color: Color(0xFF169FC4),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startRoute({
    required ParkingModel parking,
    required PlanType plan,
    required SelectedServices selected,
    required double total,
    required double userLocationLat,
    required double userLocationLng,
  }) async {
    final account = ref.read(accountProvider);
    if (!account.hasActiveVehicle) {
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      final messenger = ScaffoldMessenger.of(context);

      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            "Cadastre um veiculo ativo para realizar uma reserva.",
          ),
          action: SnackBarAction(
            label: "Veiculos",
            onPressed: () {
              rootNavigator.push(
                MaterialPageRoute(builder: (_) => const VehiclesPage()),
              );
            },
          ),
        ),
      );
      return;
    }

    final routeService = RouteService();

    final minutes = await routeService.calculateRouteTime();

    if (!mounted) return;

    await ref
        .read(preReservationProvider.notifier)
        .createPreReservation(
          parkingId: parking.id,
          parkingName: parking.name,
          routeMinutes: minutes,
        );

    if (!mounted) return;

    String? reservationId;
    var serverTotal = total;
    var platformFeeAmount = 0.0;

    try {
      final response = await ref.read(apiServiceProvider).post(
        "/reservations/pre-checkin",
        {
          "parking_id": parking.id,
          "route_minutes": minutes,
          "estimated_total": total,
          "spot_type": "uncovered",
          "pricing_plan": plan.name,
          "duration_hours": 1,
          "service_codes": [
            if (selected.carWash) "car_wash",
            if (selected.tourGuide) "tour_guide",
            if (selected.transport) "transport",
          ],
        },
      );
      reservationId = response["id"] as String?;
      serverTotal = (response["final_total"] as num?)?.toDouble() ?? total;
      platformFeeAmount =
          (response["platform_fee_amount"] as num?)?.toDouble() ?? 0;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Reserva local criada. A API de bloqueio será sincronizada depois.",
            ),
          ),
        );
      }
    }

    if (!mounted) return;

    Navigator.of(context).pop();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoutePreviewPage(
          preCheckin: PreCheckinModel(
            parking: parking,
            plan: plan,
            carWash: selected.carWash,
            tourGuide: selected.tourGuide,
            transport: selected.transport,
            total: serverTotal,
            reservationId: reservationId,
            platformFeeAmount: platformFeeAmount,
            userLocationLat: userLocationLat,
            userLocationLng: userLocationLng,
          ),
        ),
      ),
    );
  }
}

Widget _serviceChip(String label, IconData icon) {
  return Chip(
    avatar: Icon(icon, size: 16, color: const Color(0xFF169FC4)),
    label: Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    ),
    backgroundColor: const Color(0xFFEAFBFF),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}
