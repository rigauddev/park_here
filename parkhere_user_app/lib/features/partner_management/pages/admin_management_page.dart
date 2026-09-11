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
  Map<String, dynamic> _overview = {};
  List<Map<String, dynamic>> _operatorRequests = [];
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
      final overview = await _api.getAuthorizedMap('/admin/platform-fees/overview', token);
      final requests = await _api.getAuthorized('/admin/platform-fees/operator-packages/requests', token);
      if (mounted) {
        setState(() {
          _fees = rows.cast<Map<String, dynamic>>();
          _overview = overview;
          _operatorRequests = requests.cast<Map<String, dynamic>>();
        });
      }
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
                  if (_overview.isNotEmpty)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.insights),
                        title: Text('${_overview['companies']} empresas · ${_overview['parkings']} estacionamentos'),
                        subtitle: Text('${_overview['active_parkings']} unidades ativas · ${_overview['users']} usuários'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text('Solicitações de operadores', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  if (_operatorRequests.isEmpty)
                    const Card(child: ListTile(title: Text('Nenhuma solicitação pendente.')))
                  else
                    for (final request in _operatorRequests)
                      Card(child: ListTile(
                        leading: const Icon(Icons.groups),
                        title: Text('${request['quantity']} operador(es) · ${request['package_type']}'),
                        subtitle: Text('Empresa ${request['tenant_id']} · ${request['status']}${request['has_receipt'] == true ? ' · comprovante anexado' : ''}'),
                        trailing: request['status'] == 'pending_review' ? Wrap(children: [
                          IconButton(tooltip: 'Aprovar', onPressed: () => _reviewOperatorRequest(request['id'] as String, 'approve'), icon: const Icon(Icons.check, color: Colors.green)),
                          IconButton(tooltip: 'Recusar', onPressed: () => _reviewOperatorRequest(request['id'] as String, 'reject'), icon: const Icon(Icons.close, color: Colors.red)),
                        ]) : null,
                      )),
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
                        onTap: () => _editFee(fee),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _reviewOperatorRequest(String id, String decision) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    await _api.postAuthorized('/admin/platform-fees/operator-packages/requests/$id/$decision', {}, token);
    await _load();
  }

  Future<void> _editFee(Map<String, dynamic> fee) async {
    final percentage = TextEditingController(text: '${fee['percentage'] ?? 0}');
    final fixed = TextEditingController(text: '${fee['fixed_amount'] ?? 0}');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Taxa: ${fee['service_type']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: percentage, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Percentual (%)')),
          TextField(controller: fixed, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor fixo (R\$)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (result != true) return;
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    await _api.putAuthorized('/admin/platform-fees/${fee['service_type']}', {
      'service_type': fee['service_type'],
      'fee_mode': fee['fee_mode'] ?? 'hybrid',
      'percentage': double.tryParse(percentage.text.replaceAll(',', '.')) ?? 0,
      'fixed_amount': double.tryParse(fixed.text.replaceAll(',', '.')) ?? 0,
      'min_fee': fee['min_fee'] ?? 0,
      'max_fee': fee['max_fee'],
      'is_active': fee['is_active'] ?? true,
    }, token);
    await _load();
  }
}
