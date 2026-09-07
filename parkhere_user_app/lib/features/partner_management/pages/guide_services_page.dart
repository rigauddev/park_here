import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

class GuideServicesPage extends ConsumerStatefulWidget {
  const GuideServicesPage({super.key});
  @override
  ConsumerState<GuideServicesPage> createState() => _GuideServicesPageState();
}

class _GuideServicesPageState extends ConsumerState<GuideServicesPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _services = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    final result = await _api.getAuthorized('/partners/guide/services', token);
    if (mounted) {
      setState(() => _services = result.cast<Map<String, dynamic>>());
    }
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final price = TextEditingController();
    final duration = TextEditingController();
    final schedule = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo serviço turístico'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Valor (R\$)'),
              ),
              TextField(
                controller: duration,
                decoration: const InputDecoration(labelText: 'Duração'),
              ),
              TextField(
                controller: schedule,
                decoration: const InputDecoration(
                  labelText: 'Agenda (ex.: seg-sex 08:00-18:00)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    final amount = double.tryParse(price.text.replaceAll(',', '.')) ?? 0;
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    await _api.postAuthorized('/partners/guide/services', {
      'name': name.text,
      'description': description.text,
      'price': amount,
      'duration_minutes': duration.text,
      'schedule': {'description': schedule.text.trim()},
      'is_active': true,
    }, token);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Serviços turísticos')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _add,
      icon: const Icon(Icons.add),
      label: const Text('Novo serviço'),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final service in _services)
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.tour),
                    title: Text(service['name'] as String? ?? ''),
                    subtitle: Text(service['description'] as String? ?? ''),
                    isThreeLine: true,
                    trailing: Text(
                      'R\$ ${((service['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                    ),
                  ),
                  if ((service['schedule'] as Map?)?['description'] != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 72, bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Agenda: ${(service['schedule'] as Map)['description']}',
                          style: const TextStyle(color: Colors.black54),
                        ),
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
