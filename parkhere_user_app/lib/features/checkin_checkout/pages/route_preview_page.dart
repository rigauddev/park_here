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
              'Ao iniciar, a pré-reserva será enviada ao estacionamento com o tempo estimado da rota + 5 minutos.',
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red, content: Text(message)),
    );
  }
}
