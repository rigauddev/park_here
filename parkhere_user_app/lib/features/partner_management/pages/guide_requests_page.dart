import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

class GuideRequestsPage extends ConsumerStatefulWidget {
  const GuideRequestsPage({super.key});
  @override
  ConsumerState<GuideRequestsPage> createState() => _GuideRequestsPageState();
}

class _GuideRequestsPageState extends ConsumerState<GuideRequestsPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    final rows = await _api.getAuthorized('/partners/guide/requests', token);
    if (mounted) {
      setState(() {
        _requests = rows.cast<Map<String, dynamic>>();
        _loading = false;
      });
    }
  }

  Future<void> _approve(Map<String, dynamic> request) async {
    final type = ValueNotifier('percentage');
    final value = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Definir comissão'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: type,
              builder: (_, selected, __) => DropdownButtonFormField<String>(
                initialValue: selected,
                items: const [
                  DropdownMenuItem(
                    value: 'percentage',
                    child: Text('Percentual (%)'),
                  ),
                  DropdownMenuItem(
                    value: 'fixed',
                    child: Text('Valor fixo (R\$)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) type.value = v;
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: value,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Valor da comissão',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aprovar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final amount = double.tryParse(value.text.replaceAll(',', '.'));
    if (amount == null || amount < 0) return;
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    await _api.postAuthorized(
      '/partners/guide/links/${request['id']}/approve',
      {'commission_type': type.value, 'commission_value': amount},
      token,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final request in _requests)
                  Card(
                    child: ListTile(
                      title: Text(request['guide_name'] as String? ?? 'Guia'),
                      subtitle: Text(
                        '${request['parking_name']}\n${request['guide_email']}',
                      ),
                      isThreeLine: true,
                      trailing: request['status'] == 'pending'
                          ? FilledButton(
                              onPressed: () => _approve(request),
                              child: const Text('Aprovar'),
                            )
                          : Chip(
                              label: Text(request['status'] as String? ?? ''),
                            ),
                    ),
                  ),
              ],
            ),
          );
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitações de guias')),
      body: content,
    );
  }
}
