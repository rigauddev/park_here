import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/location_service.dart';
import '../../checkin_checkout/models/pre_checkin_model.dart';
import '../../checkin_checkout/pages/checkin_page.dart';

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
                onPressed: _loading ? null : _validateAndGoToCheckin,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Fazer check-in",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CheckinPage(preCheckin: widget.preCheckin),
                    ),
                  );
                },
                icon: const Icon(Icons.lock_clock),
                label: const Text("Check-in antecipado e pagamento"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _validateAndGoToCheckin() async {
    try {
      setState(() => _loading = true);

      final locationService = LocationService();

      final userPosition = Position(
        latitude: -12.9704,
        longitude: -38.5124,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );

      final latitude = widget.preCheckin.parking.lat;
      final longitude = widget.preCheckin.parking.lng;

      final distance = locationService.calculateDistance(
        startLat: userPosition.latitude,
        startLng: userPosition.longitude,
        endLat: latitude,
        endLng: longitude,
      );

      const allowedRadius = 30.0;

      if (distance > allowedRadius) {
        throw CheckinCheckoutError(
          "Você precisa estar no estacionamento para realizar o check-in.\nDistância atual: ${distance.toStringAsFixed(1)}m",
        );
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckinPage(preCheckin: widget.preCheckin),
        ),
      );
    } catch (e) {
      _showError(
        e is CheckinCheckoutError ? e.message : "Erro ao validar localização.",
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectRoute(String appName) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onRouteSelected?.call();
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
