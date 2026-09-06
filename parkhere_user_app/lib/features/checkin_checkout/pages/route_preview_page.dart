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

            const Text("Deseja abrir a rota em qual aplicativo?"),

            const SizedBox(height: 15),

            ListTile(
              leading: const Icon(Icons.map),
              title: const Text("Google Maps"),
              onTap: () => _selectRoute('Google Maps'),
            ),

            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text("Waze"),
              onTap: () => _selectRoute('Waze'),
            ),

            ListTile(
              leading: const Icon(Icons.public),
              title: const Text("OpenStreetMap"),
              onTap: () => _selectRoute('OpenStreetMap'),
            ),

            const Spacer(),
            const Text(
              'O check-in só pode ser realizado no estacionamento, pela tela de reservas.',
              textAlign: TextAlign.center,
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red, content: Text(message)),
    );
  }
}
