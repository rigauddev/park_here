import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../checkin_checkout/models/pre_checkin_model.dart';

class RoutePreviewPage extends StatefulWidget {
  final PreCheckinModel preCheckin;
  final Future<void> Function()? onRouteSelected;

  const RoutePreviewPage({
    super.key,
    required this.preCheckin,
    this.onRouteSelected,
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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "Destino: ${parking.name}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

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

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _openMapChooser,
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Iniciar rota'),
              ),
            ),
          ],
        ),
      ),
    );
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
