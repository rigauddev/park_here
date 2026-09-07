import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/routes/route_service.dart';
import '../../../core/services/location_service.dart';
import '../../account/pages/vehicles_page.dart';
import '../../account/providers/account_provider.dart';
import '../../auth/providers/auth_provider.dart';
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
  static const _valencaCenter = LatLng(-13.3703, -39.0731);
  static const _cityCenters = {
    'valença': LatLng(-13.3703, -39.0731),
    'salvador': LatLng(-12.9777, -38.5016),
    'são paulo': LatLng(-23.5505, -46.6333),
    'curitiba': LatLng(-25.4284, -49.2733),
    'rio de janeiro': LatLng(-22.9068, -43.1729),
    'belo horizonte': LatLng(-19.9167, -43.9345),
    'porto alegre': LatLng(-30.0346, -51.2177),
    'recife': LatLng(-8.0476, -34.8770),
    'fortaleza': LatLng(-3.7319, -38.5267),
    'manaus': LatLng(-3.1190, -60.0217),
    'brasilia': LatLng(-15.7942, -47.8828),
    'goiânia': LatLng(-16.6864, -49.2643),
    'campinas': LatLng(-22.9056, -47.0616),
    'natal': LatLng(-5.7945, -35.2110),
    'florianópolis': LatLng(-27.5973, -48.5480),
    'joão pessoa': LatLng(-7.1195, -34.8450),
    'aracaju': LatLng(-10.9472, -37.0748),
    'maceió': LatLng(-9.6659, -35.7353),
    'teresina': LatLng(-5.0892, -42.8090),
    'palmas': LatLng(-10.1679, -48.3325),
    'belem': LatLng(-1.4558, -48.4902),
  };

  final mapController = MapController();
  final parkingSearchController = TextEditingController();
  LatLng? userLocation;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    try {
      final position = await LocationService().getCurrentLocation();
      if (!mounted) return;
      setState(
        () => userLocation = LatLng(position.latitude, position.longitude),
      );
      final parkings = await ref.read(parkingProvider.future);
      if (!mounted || parkings.isEmpty) return;
      final nearest = parkings.reduce((a, b) {
        final distanceA =
            math.pow(a.lat - position.latitude, 2) +
            math.pow(a.lng - position.longitude, 2);
        final distanceB =
            math.pow(b.lat - position.latitude, 2) +
            math.pow(b.lng - position.longitude, 2);
        return distanceA < distanceB ? a : b;
      });
      ref.read(selectedCityProvider.notifier).state = nearest.city;
      await ref.read(parkingProvider.notifier).searchByCity(nearest.city);
    } catch (_) {
      if (!mounted) return;
      setState(() => userLocation = _valencaCenter);
    }
  }

  @override
  void dispose() {
    parkingSearchController.dispose();
    super.dispose();
  }

  String _normalizeSearch(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c')
        .trim();
  }

  void _focusSearchResults(List<ParkingModel> parkings, String query) {
    final normalizedQuery = _normalizeSearch(query);
    if (normalizedQuery.isEmpty) {
      mapController.move(userLocation ?? _valencaCenter, 14);
      return;
    }

    final match = parkings.cast<ParkingModel?>().firstWhere((parking) {
      if (parking == null) return false;
      return _normalizeSearch(parking.name).contains(normalizedQuery) ||
          _normalizeSearch(parking.city).contains(normalizedQuery);
    }, orElse: () => null);

    if (match != null) {
      mapController.move(LatLng(match.lat, match.lng), 13);
      return;
    }

    final cityCenter = _cityCenterFor(query);
    if (cityCenter != null) {
      mapController.move(cityCenter, 12);
    }
  }

  LatLng? _cityCenterFor(String city) {
    final normalizedCity = _normalizeSearch(city);
    if (normalizedCity.isEmpty) return null;

    for (final entry in _cityCenters.entries) {
      if (entry.key.contains(normalizedCity) ||
          normalizedCity.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  List<String> _normalizedCityList(List<ParkingModel> currentParkings) {
    final citiesByKey = <String, String>{};

    for (final city in [
      ...currentParkings.map((parking) => parking.city),
      ..._cityCenters.keys,
      'Valença',
      'Salvador',
      'São Paulo',
      'Curitiba',
    ]) {
      if (city.trim().isEmpty) continue;
      final key = _normalizeSearch(city);
      citiesByKey.putIfAbsent(key, () => city.trim());
    }

    final cities = citiesByKey.values.toList();
    cities.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return cities;
  }

  Future<void> _openCitySelector(List<ParkingModel> currentParkings) async {
    final currentCity = ref.read(selectedCityProvider);
    final controller = TextEditingController(text: currentCity);

    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        final cities = _normalizedCityList(currentParkings);

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Selecionar cidade',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Cidade',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                    onSubmitted: (value) =>
                        Navigator.pop(context, value.trim()),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final city in cities)
                        ActionChip(
                          avatar: const Icon(Icons.place_outlined, size: 18),
                          label: Text(city),
                          onPressed: () => Navigator.pop(context, city),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    controller.dispose();
    if (selected == null || !mounted) return;
    await _applyCitySearch(selected);
  }

  Future<void> _applyCitySearch(String city) async {
    final normalizedCity = city.trim();
    ref.read(selectedCityProvider.notifier).state = normalizedCity;
    ref.read(searchQueryProvider.notifier).state = "";
    parkingSearchController.clear();

    await ref.read(parkingProvider.notifier).searchByCity(normalizedCity);
    if (!mounted) return;

    final parkings = ref.read(parkingProvider).value ?? const <ParkingModel>[];
    if (parkings.isNotEmpty) {
      // Preserve the canonical spelling returned by the API (for example,
      // typing "sao paulo" displays "São Paulo").
      ref.read(selectedCityProvider.notifier).state = parkings.first.city;
      _focusSearchResults(parkings, normalizedCity);
      return;
    }

    final cityCenter = _cityCenterFor(normalizedCity);
    if (cityCenter != null) {
      mapController.move(cityCenter, 12);
      return;
    }

    mapController.move(userLocation ?? _valencaCenter, 12);
  }

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
            final areaPreference = ref.watch(selectedAreaPreferenceProvider);

            // ===============================
            // ✅ ETAPA 1 — Escolher Plano
            // ===============================
            if (plan == null) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                      "Escolha a área da vaga:",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<AreaPreference>(
                      initialValue: areaPreference,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de vaga',
                        prefixIcon: Icon(Icons.local_parking_outlined),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: AreaPreference.any,
                          child: Text('Qualquer (${parking.availableSpots})'),
                        ),
                        if (parking.coveredSpots > 0)
                          DropdownMenuItem(
                            value: AreaPreference.covered,
                            child: Text('Coberta (${parking.coveredSpots})'),
                          ),
                        if (parking.uncoveredSpots > 0)
                          DropdownMenuItem(
                            value: AreaPreference.uncovered,
                            child: Text(
                              'Descoberta (${parking.uncoveredSpots})',
                            ),
                          ),
                        if (parking.hasVipSpots && parking.vipSpots > 0)
                          DropdownMenuItem(
                            value: AreaPreference.vip,
                            child: Text('VIP (${parking.vipSpots})'),
                          ),
                        if (parking.largeSpots > 0)
                          DropdownMenuItem(
                            value: AreaPreference.large,
                            child: Text(
                              'Espaço grande (${parking.largeSpots})',
                            ),
                          ),
                        if (parking.motoHomeSpots > 0)
                          DropdownMenuItem(
                            value: AreaPreference.motorhome,
                            child: Text('Motorhome (${parking.motoHomeSpots})'),
                          ),
                        if (parking.busSpots > 0)
                          DropdownMenuItem(
                            value: AreaPreference.bus,
                            child: Text('Ônibus (${parking.busSpots})'),
                          ),
                        if (parking.pickupSpots > 0)
                          DropdownMenuItem(
                            value: AreaPreference.pickup,
                            child: Text('Pickup (${parking.pickupSpots})'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          ref
                                  .read(selectedAreaPreferenceProvider.notifier)
                                  .state =
                              value;
                        }
                      },
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "Escolha seu plano:",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    _PlanChoiceCard(
                      icon: Icons.access_time,
                      title: 'Avulso por hora',
                      subtitle: 'Ideal para paradas rápidas',
                      price:
                          'R\$ ${parking.pricing.firstHourPrice.toStringAsFixed(2)}',
                      badge: 'Mais flexível',
                      highlighted: true,
                      onTap: () =>
                          ref.read(selectedPlanProvider.notifier).state =
                              PlanType.hourly,
                    ),
                    const SizedBox(height: 10),
                    _PlanChoiceCard(
                      icon: Icons.calendar_today,
                      title: 'Diária',
                      subtitle: 'Para permanecer o dia todo',
                      price:
                          'R\$ ${parking.pricing.dailyPrice.toStringAsFixed(2)}',
                      badge: 'Dia completo',
                      onTap: () {
                        ref.read(selectedDailyDaysProvider.notifier).state = 1;
                        ref.read(selectedPlanProvider.notifier).state =
                            PlanType.daily;
                      },
                    ),
                    const SizedBox(height: 10),
                    _PlanChoiceCard(
                      icon: Icons.calendar_month,
                      title: 'Mensal',
                      subtitle: 'Melhor para rotina frequente',
                      price:
                          'R\$ ${parking.pricing.monthlyPrice.toStringAsFixed(2)}',
                      badge: 'Recorrência',
                      onTap: () =>
                          ref.read(selectedPlanProvider.notifier).state =
                              PlanType.monthly,
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              );
            }

            // ===============================
            // ✅ ETAPA 2 — Detalhes do Plano
            // ===============================

            final dailyDays = ref.watch(selectedDailyDaysProvider);
            double total = 0;

            switch (plan) {
              case PlanType.hourly:
                total = _priceForArea(parking, areaPreference, hourly: true);
                break;
              case PlanType.daily:
                total = _priceForArea(parking, areaPreference) * dailyDays;
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "📅 Diária: R\$ ${parking.pricing.dailyPrice} por dia",
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: dailyDays,
                          decoration: const InputDecoration(
                            labelText: 'Quantidade de diárias / Number of days',
                          ),
                          items: [
                            for (var day = 1; day <= 30; day++)
                              DropdownMenuItem(value: day, child: Text('$day')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              ref
                                      .read(selectedDailyDaysProvider.notifier)
                                      .state =
                                  value;
                            }
                          },
                        ),
                      ],
                    ),

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
                          dailyDays: dailyDays,
                          userLocationLat: position.latitude,
                          userLocationLng: position.longitude,
                        );
                      },
                      child: const Text(
                        "Iniciar rota",
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
    final selectedCity = ref.watch(selectedCityProvider);

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

          final query = _normalizeSearch(searchQuery);
          final filteredParkings = parkings.where((p) {
            if (filter.covered && !p.hasCoveredArea) return false;
            if (filter.vip && !p.hasVipSpots) return false;
            if (query.isEmpty) return true;
            return _normalizeSearch(p.name).contains(query);
          }).toList();

          filteredParkings.sort((a, b) {
            if (userLocation != null) {
              final distance = const Distance();
              final aDistance = distance.as(
                LengthUnit.Meter,
                userLocation!,
                LatLng(a.lat, a.lng),
              );
              final bDistance = distance.as(
                LengthUnit.Meter,
                userLocation!,
                LatLng(b.lat, b.lng),
              );
              return aDistance.compareTo(bDistance);
            }
            return b.rating.compareTo(a.rating);
          });
          final selectedCityCenter = _cityCenterFor(selectedCity);
          final showSelectedCityMarker =
              selectedCityCenter != null && filteredParkings.isEmpty;

          return Stack(
            children: [
              // ✅ MAPA FULLSCREEN
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: userLocation ?? _valencaCenter,
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png",
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'br.com.rptech.parkhere_user_app',
                  ),

                  MarkerLayer(
                    markers: [
                      if (userLocation != null)
                        Marker(
                          point: userLocation!,
                          child: const _UserLocationMarker(),
                        ),
                      if (showSelectedCityMarker)
                        Marker(
                          point: selectedCityCenter,
                          width: 54,
                          height: 54,
                          child: const _CitySearchMarker(),
                        ),
                      ...filteredParkings.map((parking) {
                        return Marker(
                          point: LatLng(parking.lat, parking.lng),
                          width: 54,
                          height: 64,
                          child: GestureDetector(
                            onTap: () => openParkingDetails(
                              context,
                              parking,
                              userLocation ?? _valencaCenter,
                            ),
                            child: _ParkingMarker(parking: parking),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),

              // ✅ CAMPO DE BUSCA + FILTRO FIXO NO TOPO
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _CitySelectorButton(
                              city: selectedCity,
                              onTap: () => _openCitySelector(parkings),
                            ),
                          ),
                          const SizedBox(width: 10),
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
                              tooltip: 'Filtros',
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
                      const SizedBox(height: 10),
                      TextField(
                        controller: parkingSearchController,
                        decoration: InputDecoration(
                          hintText: "Buscar estacionamento...",
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    parkingSearchController.clear();
                                    ref
                                            .read(searchQueryProvider.notifier)
                                            .state =
                                        "";
                                    _focusSearchResults(parkings, selectedCity);
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
                          ref.read(searchQueryProvider.notifier).state = value;
                          if (value.trim().isEmpty) {
                            _focusSearchResults(parkings, selectedCity);
                            return;
                          }
                          final match = parkings.where((parking) {
                            return _normalizeSearch(
                              parking.name,
                            ).contains(_normalizeSearch(value));
                          }).toList();
                          _focusSearchResults(match, value);
                        },
                      ),
                      if (selectedCity.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAFBFF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFD9E8F0),
                              ),
                            ),
                            child: Text(
                              'Cidade selecionada: $selectedCity',
                              style: const TextStyle(
                                color: Color(0xFF102657),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              Positioned(
                right: 14,
                bottom: 190,
                child: FloatingActionButton.small(
                  heroTag: 'home-map-location',
                  tooltip: 'Usar minha localização',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF169FC4),
                  onPressed: () async {
                    if (userLocation == null) await _loadUserLocation();
                    if (!mounted) return;
                    mapController.move(userLocation ?? _valencaCenter, 15);
                  },
                  child: const Icon(Icons.my_location),
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
                          child: filteredParkings.isEmpty
                              ? _EmptyCitySearch(
                                  city: selectedCity,
                                  query: searchQuery,
                                  scrollController: scrollController,
                                )
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: filteredParkings.length,
                                  itemBuilder: (context, index) {
                                    final parking = filteredParkings[index];

                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
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
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    parking.name,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  "${parking.city} · Vagas: ${parking.availableSpots}",
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

                                            _ArrivalPreview(
                                              parking: parking,
                                              userLocation:
                                                  userLocation ??
                                                  _valencaCenter,
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
                                                  _serviceChip(
                                                    "Guia",
                                                    Icons.map,
                                                  ),

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
                                                onPressed: () =>
                                                    openParkingDetails(
                                                      context,
                                                      parking,
                                                      userLocation ??
                                                          _valencaCenter,
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
    required int dailyDays,
    required double userLocationLat,
    required double userLocationLng,
  }) async {
    final areaPreference = ref.read(selectedAreaPreferenceProvider);
    String? guideUserId;
    if (selected.tourGuide) {
      try {
        final guides = await ref
            .read(apiServiceProvider)
            .get('/parkings/${parking.id}/guides');
        if (!mounted) return;
        if (guides.isNotEmpty) {
          final selectedGuide = await showDialog<String>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('Indicar guia / Select a guide'),
              children: [
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, '__none__'),
                  child: const Text('Sem indicação / No guide'),
                ),
                for (final rawGuide in guides)
                  SimpleDialogOption(
                    onPressed: () =>
                        Navigator.pop(context, rawGuide['id'] as String),
                    child: Text(
                      (rawGuide['name'] as String?)?.trim().isNotEmpty == true
                          ? rawGuide['name'] as String
                          : rawGuide['email'] as String? ?? 'Guia',
                    ),
                  ),
              ],
            ),
          );
          if (selectedGuide == null) return;
          if (selectedGuide != '__none__') guideUserId = selectedGuide;
        }
      } catch (_) {
        // A indicação é opcional; a reserva pode seguir sem guia.
      }
    }
    await ref.read(accountProvider.notifier).syncVehicles();
    if (!mounted) return;
    final account = ref.read(accountProvider);
    final activeVehicle = account.activeVehicle;
    if (activeVehicle == null) {
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

    final minutes = await routeService.calculateRouteTime(
      startLat: userLocationLat,
      startLng: userLocationLng,
      endLat: parking.lat,
      endLng: parking.lng,
    );

    if (!mounted) return;

    if (!mounted) return;

    Navigator.of(context).pop();

    final preCheckin = PreCheckinModel(
      parking: parking,
      plan: plan,
      carWash: selected.carWash,
      tourGuide: selected.tourGuide,
      transport: selected.transport,
      total: total,
      reservationId: null,
      platformFeeAmount: 0,
      userLocationLat: userLocationLat,
      userLocationLng: userLocationLng,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoutePreviewPage(
          preCheckin: preCheckin,
          onRouteSelected: () async {
            await ref
                .read(preReservationProvider.notifier)
                .createPreReservation(
                  parkingId: parking.id,
                  parkingName: parking.name,
                  routeMinutes: minutes,
                );
            final token = ref.read(authProvider).accessToken;
            if (token == null) {
              throw Exception('Sessao expirada. Entre novamente.');
            }
            final response = await ref.read(apiServiceProvider).postAuthorized(
              '/reservations/pre-checkin',
              {
                'parking_id': parking.id,
                'route_minutes': minutes,
                'estimated_total': total,
                'vehicle_id': activeVehicle.id,
                'spot_type': switch (areaPreference) {
                  AreaPreference.covered => 'covered',
                  AreaPreference.uncovered => 'uncovered',
                  AreaPreference.vip => 'vip',
                  AreaPreference.large => 'large',
                  AreaPreference.motorhome => 'motorhome',
                  AreaPreference.bus => 'bus',
                  AreaPreference.pickup => 'pickup',
                  AreaPreference.any => 'any',
                },
                'area_preference': areaPreference.name,
                'pricing_plan': plan.name,
                'duration_hours': plan == PlanType.daily ? dailyDays * 24 : 1,
                if (guideUserId != null) 'guide_user_id': guideUserId,
                'service_codes': [
                  if (selected.carWash) 'car_wash',
                  if (selected.tourGuide) 'tour_guide',
                  if (selected.transport) 'transport',
                ],
              },
              token,
            );
            preCheckin.reservationId = response['id'] as String?;
          },
        ),
      ),
    );
  }

  double _priceForArea(
    ParkingModel parking,
    AreaPreference area, {
    bool hourly = false,
  }) {
    if (hourly) {
      return area == AreaPreference.covered
          ? parking.pricing.coveredFirstHourPrice
          : area == AreaPreference.uncovered
          ? parking.pricing.uncoveredFirstHourPrice
          : parking.pricing.firstHourPrice;
    }
    return area == AreaPreference.covered
        ? parking.pricing.coveredDailyPrice
        : area == AreaPreference.uncovered
        ? parking.pricing.uncoveredDailyPrice
        : parking.pricing.dailyPrice;
  }
}

class _CitySelectorButton extends StatelessWidget {
  final String city;
  final VoidCallback onTap;

  const _CitySelectorButton({required this.city, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = city.trim().isEmpty ? 'Selecionar cidade' : city.trim();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                blurRadius: 6,
                color: Colors.black.withValues(alpha: 0.05),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_city_outlined,
                color: Color(0xFF169FC4),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF102657),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: Color(0xFF55708F)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParkingMarker extends StatelessWidget {
  final ParkingModel parking;

  const _ParkingMarker({required this.parking});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF169FC4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33102657),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'P',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        Container(width: 3, height: 8, color: const Color(0xFF169FC4)),
      ],
    );
  }
}

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF102657),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x33102657), blurRadius: 10)],
      ),
      child: const Icon(Icons.navigation, color: Colors.white, size: 14),
    );
  }
}

class _CitySearchMarker extends StatelessWidget {
  const _CitySearchMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF169FC4), width: 3),
        boxShadow: const [BoxShadow(color: Color(0x33102657), blurRadius: 12)],
      ),
      child: const Icon(
        Icons.location_city,
        color: Color(0xFF169FC4),
        size: 26,
      ),
    );
  }
}

class _EmptyCitySearch extends StatelessWidget {
  final String city;
  final String query;
  final ScrollController scrollController;

  const _EmptyCitySearch({
    required this.city,
    required this.query,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final hasCity = city.trim().isNotEmpty;
    final target = hasCity ? city.trim() : query.trim();
    final title = target.isEmpty ? 'Nenhum estacionamento encontrado' : target;
    final message = hasCity
        ? 'Ainda não temos estacionamentos cadastrados nesta cidade.'
        : 'Selecione uma cidade ou ajuste a busca para encontrar estacionamentos.';

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      children: [
        const Icon(
          Icons.location_off_outlined,
          color: Color(0xFF169FC4),
          size: 34,
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF102657),
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF55708F)),
        ),
      ],
    );
  }
}

class _ArrivalPreview extends StatelessWidget {
  final ParkingModel parking;
  final LatLng userLocation;

  const _ArrivalPreview({required this.parking, required this.userLocation});

  @override
  Widget build(BuildContext context) {
    final meters = LocationService().calculateDistance(
      startLat: userLocation.latitude,
      startLng: userLocation.longitude,
      endLat: parking.lat,
      endLng: parking.lng,
    );
    final minutes = (meters / 350).ceil().clamp(3, 90).toInt();
    final arrival = DateTime.now().add(Duration(minutes: minutes));
    final hour = arrival.hour.toString().padLeft(2, '0');
    final minute = arrival.minute.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAFBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.route, size: 18, color: Color(0xFF169FC4)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Previsão de chegada: $minutes minutos · ${hour}h$minute',
              style: const TextStyle(
                color: Color(0xFF102657),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String price;
  final String badge;
  final bool highlighted;
  final VoidCallback onTap;

  const _PlanChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.badge,
    this.highlighted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = highlighted
        ? const Color(0xFF169FC4)
        : const Color(0xFF102657);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFFEAFBFF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlighted
                ? const Color(0xFF64D6E6)
                : const Color(0xFFD9E8F0),
            width: highlighted ? 1.6 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10102657),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: accent.withValues(alpha: 0.1),
              foregroundColor: accent,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF102657),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF55708F)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    price,
                    style: TextStyle(
                      color: accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
