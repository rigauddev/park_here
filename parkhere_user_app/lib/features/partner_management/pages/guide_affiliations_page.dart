import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../auth/providers/auth_provider.dart';

class GuideAffiliationsPage extends ConsumerStatefulWidget {
  const GuideAffiliationsPage({super.key});

  @override
  ConsumerState<GuideAffiliationsPage> createState() =>
      _GuideAffiliationsPageState();
}

class _GuideAffiliationsPageState extends ConsumerState<GuideAffiliationsPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _parkings = [];
  bool _loading = true;
  final _cityController = TextEditingController();
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    final query = <String, String>{};
    if (_cityController.text.trim().length >= 2) {
      query['city'] = _cityController.text.trim();
    }
    if (_latitude != null && _longitude != null) {
      query['latitude'] = '$_latitude';
      query['longitude'] = '$_longitude';
    }
    final suffix = query.isEmpty
        ? ''
        : '?${query.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
    final result = await _api.getAuthorized(
      '/partners/guide/parkings$suffix',
      token,
    );
    if (mounted) {
      setState(() {
        _parkings = result.cast<Map<String, dynamic>>();
        _loading = false;
      });
    }
  }

  Future<void> _request(String parkingId) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    await _api.postAuthorized('/partners/guide/parkings/$parkingId', {}, token);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estacionamentos / Parking partners')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            labelText: 'Cidade / City',
                            prefixIcon: Icon(Icons.location_city),
                          ),
                          onSubmitted: (_) => _load(),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Usar minha localização',
                        onPressed: () async {
                          final position = await LocationService()
                              .getCurrentLocation();
                          if (!mounted) return;
                          setState(() {
                            _latitude = position.latitude;
                            _longitude = position.longitude;
                          });
                          await _load();
                        },
                        icon: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Solicite afiliação aos estacionamentos onde você atua. A comissão será definida pelo estabelecimento ao aprovar.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  for (final parking in _parkings)
                    _ParkingAffiliationCard(
                      parking: parking,
                      onRequest: _request,
                    ),
                ],
              ),
            ),
    );
  }
}

class _ParkingAffiliationCard extends StatelessWidget {
  final Map<String, dynamic> parking;
  final Future<void> Function(String) onRequest;

  const _ParkingAffiliationCard({
    required this.parking,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final status = parking['status'] as String? ?? 'not_linked';
    final label = switch (status) {
      'pending' => 'Solicitação pendente',
      'approved' => 'Aprovado',
      _ => 'Solicitar afiliação',
    };
    final offers =
        (parking['offer_terms'] as Map?)?.cast<String, dynamic>() ?? {};
    final offerText = offers.isEmpty
        ? 'Taxa a definir pelo estabelecimento'
        : offers.entries
              .map((entry) {
                final term = (entry.value as Map).cast<String, dynamic>();
                final value = term['commission_value'];
                final suffix = term['commission_type'] == 'percentage'
                    ? '%'
                    : ' R\$';
                return '${_periodLabel(entry.key)}: $value$suffix';
              })
              .join('  •  ');
    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_parking),
        title: Text(parking['name'] as String? ?? 'Estacionamento'),
        subtitle: Text(
          '${parking['city'] as String? ?? ''}\nOferta: $offerText',
        ),
        isThreeLine: true,
        trailing: status == 'not_linked'
            ? FilledButton(
                onPressed: () => onRequest(parking['id'] as String),
                child: Text(label),
              )
            : Chip(label: Text(label)),
      ),
    );
  }

  static String _periodLabel(String value) => switch (value) {
    'daily' => 'Diária',
    'weekly' => 'Semanal',
    'monthly' => 'Mensal',
    _ => 'Longa duração',
  };
}
