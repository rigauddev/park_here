import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';

class AdminManagementPage extends ConsumerStatefulWidget {
  const AdminManagementPage({super.key});

  @override
  ConsumerState<AdminManagementPage> createState() =>
      _AdminManagementPageState();
}

class _AdminManagementPageState extends ConsumerState<AdminManagementPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _fees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    try {
      final rows = await _api.getAuthorized('/admin/platform-fees', token);
      if (mounted) setState(() => _fees = rows.cast<Map<String, dynamic>>());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestão do sistema / Admin panel')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.admin_panel_settings),
                      title: Text('Funcionalidades dos planos'),
                      subtitle: Text(
                        'A área de liberação de planos está preparada para receber as solicitações dos parceiros.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Taxas globais',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  for (final fee in _fees)
                    Card(
                      child: ListTile(
                        title: Text(fee['service_type'] as String? ?? ''),
                        subtitle: Text(
                          '${fee['percentage'] ?? 0}% + R\$ ${fee['fixed_amount'] ?? 0}',
                        ),
                        trailing: Icon(
                          fee['is_active'] == true
                              ? Icons.check_circle
                              : Icons.pause_circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
