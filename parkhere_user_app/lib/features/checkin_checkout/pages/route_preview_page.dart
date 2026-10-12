import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../checkin_checkout/models/pre_checkin_model.dart';
import '../../payments/pages/payment_page.dart';
import '../../parking_search/models/payment_plan_enum.dart';

class RoutePreviewPage extends StatefulWidget {
  final PreCheckinModel preCheckin;
  final Future<void> Function()? onRouteSelected;
  final Future<String?> Function(DateTime arrival)? onGuaranteeReservation;

  const RoutePreviewPage({
    super.key,
    required this.preCheckin,
    this.onRouteSelected,
    this.onGuaranteeReservation,
  });

  @override
  State<RoutePreviewPage> createState() => _RoutePreviewPageState();
}

class _RoutePreviewPageState extends State<RoutePreviewPage> {
  bool _loading = false;
  bool _acceptTerms = false;

  @override
  Widget build(BuildContext context) {
    final parking = widget.preCheckin.parking;

    return Scaffold(
      appBar: AppBar(title: const Text("Rota até o estacionamento")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Destino: ${parking.name}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(
                      (widget.preCheckin.userLocationLat + parking.lat) / 2,
                      (widget.preCheckin.userLocationLng + parking.lng) / 2,
                    ),
                    initialZoom: 13,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'br.com.rptech.parkhere_user_app',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [
                            LatLng(widget.preCheckin.userLocationLat, widget.preCheckin.userLocationLng),
                            LatLng(parking.lat, parking.lng),
                          ],
                          color: const Color(0xFF169FC4),
                          strokeWidth: 5,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(widget.preCheckin.userLocationLat, widget.preCheckin.userLocationLng),
                          child: const Icon(Icons.my_location, color: Color(0xFF169FC4)),
                        ),
                        Marker(
                          point: LatLng(parking.lat, parking.lng),
                          child: const Icon(Icons.local_parking, color: Color(0xFF102657)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            Card(
              child: ListTile(
                leading: const Icon(Icons.route_outlined),
                title: const Text('Resumo da pré-reserva'),
                subtitle: Text(
                  '${widget.preCheckin.plan.name.toUpperCase()} • R\$ ${widget.preCheckin.total.toStringAsFixed(2)}',
                ),
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Ao iniciar, a pré-reserva será enviada ao estacionamento com o tempo estimado da rota + 5 minutos. Ao chegar, retorne ao ParkHere para realizar o check-in.',
              textAlign: TextAlign.center,
            ),

            if (widget.preCheckin.plan != PlanType.hourly)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading || widget.onGuaranteeReservation == null
                      ? null
                      : _guaranteeReservation,
                  icon: const Icon(Icons.lock_clock_outlined),
                label: const Text('Confirmar reserva'),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _openMapChooser,
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Avançar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guaranteeReservation() async {
    final arrival = await _pickArrival();
    if (arrival == null || !mounted) return;
    setState(() => _loading = true);
    try {
      final accepted = await _requestTermsAcceptance();
      if (!accepted) return;
      final reservationId = await widget.onGuaranteeReservation!(arrival);
      if (!mounted || reservationId == null) return;
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            amount: widget.preCheckin.total,
            reservationId: reservationId,
            payNow: true,
            onPaymentSuccess: () async {},
          ),
        ),
      );
      if (paid == true && mounted) Navigator.pop(context, true);
    } catch (error) {
      _showError('Não foi possível garantir a reserva: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<DateTime?> _pickArrival() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now,
      helpText: 'Informe a data de chegada',
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 30))),
      helpText: 'Informe o horário de chegada',
    );
    if (time == null) return null;
    final arrival = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!arrival.isAfter(now)) {
      _showError(
        'Informe um horário de chegada futuro e dentro do funcionamento.',
      );
      return null;
    }
    return arrival;
  }

  Future<void> _selectRoute(String appName) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final accepted = await _requestTermsAcceptance();
      if (!accepted) return;
      await widget.onRouteSelected?.call();
      final destination =
          '${widget.preCheckin.parking.lat},${widget.preCheckin.parking.lng}';
      final uri = switch (appName) {
        'Waze' => Uri.parse('https://waze.com/ul?ll=$destination&navigate=yes'),
        'OpenStreetMap' => Uri.parse(
          'https://www.openstreetmap.org/directions?to=$destination',
        ),
        _ => Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$destination',
        ),
      };
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rota iniciada no $appName.')));
      Navigator.pop(context);
    } catch (error) {
      _showError('Nao foi possivel iniciar a rota: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _requestTermsAcceptance() async {
    final english = Localizations.localeOf(context).languageCode == 'en';
    final selectedTerms = <String>[
      if (widget.preCheckin.carWash)
        english
            ? 'I reviewed the provider, package, location, time, price, scope, exclusions and rescheduling/cancellation rules for the car wash.'
            : 'Revisei o prestador, pacote, local, horário, preço, escopo, itens não incluídos e regras de reagendamento/cancelamento do lava-jato.',
      if (widget.preCheckin.tourGuide)
        english
            ? 'I reviewed the provider, itinerary, duration, meeting point, price, inclusions, safety/accessibility requirements and weather/cancellation terms.'
            : 'Revisei prestador, roteiro, duração, ponto de encontro, preço, inclusões, requisitos de segurança/acessibilidade e política de clima e cancelamento.',
      if (widget.preCheckin.transport)
        english
            ? 'I reviewed the carrier, origin, destination, time, passengers, luggage, price and delay/cancellation rules.'
            : 'Revisei transportador, origem, destino, horário, passageiros, bagagem, preço e regras de atraso e cancelamento.',
    ];
    _acceptTerms = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(english ? 'Reservation terms' : 'Termos da reserva'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    english
                        ? 'I reviewed the location, parking-space category, period, vehicle plate, price, fees, arrival estimate, grace period and cancellation terms. The identified business operates the parking service; statutory rights remain.'
                        : 'Revisei unidade, categoria da vaga, período, placa, preço, taxas, previsão de chegada, tolerância e cancelamento. O estabelecimento identificado opera o estacionamento e informa as regras de guarda e permanência; continuam válidos os direitos previstos em lei.',
                  ),
                  const SizedBox(height: 12),
                  for (final term in selectedTerms) ...[
                    Text(term),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    english
                        ? 'ParkHere facilitates discovery, communication and the digital booking flow. The identified provider performs the booked service. ParkHere remains responsible for its own platform duties as required by law; this acceptance does not waive consumer rights.'
                        : 'O ParkHere facilita a descoberta, comunicação e fluxo digital da reserva. O prestador identificado executa o serviço contratado. O ParkHere mantém as obrigações próprias da plataforma conforme sua atuação e a legislação; este aceite não renuncia a direitos legais do consumidor.',
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _acceptTerms,
                    onChanged: (value) =>
                        setDialogState(() => _acceptTerms = value ?? false),
                    title: Text(
                      english
                          ? 'I reviewed and accept the terms for every service in this booking.'
                          : 'Li e aceito os termos de todos os serviços desta reserva.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(english ? 'Cancel' : 'Voltar'),
            ),
            FilledButton(
              onPressed: _acceptTerms
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: Text(
                english ? 'Accept and continue' : 'Aceitar e continuar',
              ),
            ),
          ],
        ),
      ),
    );
    return accepted == true;
  }

  Future<void> _openMapChooser() async {
    final app = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(title: Text('Escolha seu aplicativo de mapas')),
            for (final item in const [
              ('Google Maps', Icons.map),
              ('Waze', Icons.map_outlined),
              ('OpenStreetMap', Icons.public),
            ])
              ListTile(
                leading: Icon(item.$2),
                title: Text(item.$1),
                onTap: () => Navigator.pop(context, item.$1),
              ),
          ],
        ),
      ),
    );
    if (app != null) await _selectRoute(app);
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Não foi possível iniciar a rota'),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
