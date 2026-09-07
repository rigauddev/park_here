import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

class GuideDashboardPage extends ConsumerStatefulWidget {
  const GuideDashboardPage({super.key});

  @override
  ConsumerState<GuideDashboardPage> createState() => _GuideDashboardPageState();
}

class _GuideDashboardPageState extends ConsumerState<GuideDashboardPage> {
  final _api = ApiService();
  int _approved = 0;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    final rows = await _api.getAuthorized('/partners/guide/parkings', token);
    if (!mounted) return;
    setState(() {
      _approved = rows.where((item) => item['status'] == 'approved').length;
      _pending = rows.where((item) => item['status'] == 'pending').length;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dashboard do guia / Guide dashboard')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Serviços do guia turístico',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  'Estacionamentos afiliados',
                  '$_approved',
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  'Solicitações pendentes',
                  '$_pending',
                  Icons.hourglass_top,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Card(
            child: ListTile(
              leading: Icon(Icons.tour),
              title: Text('Serviços turísticos'),
              subtitle: Text(
                'Cadastre roteiros, idiomas, agenda e valores em seguida.',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _StatCard(this.title, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(title),
        ],
      ),
    ),
  );
}
