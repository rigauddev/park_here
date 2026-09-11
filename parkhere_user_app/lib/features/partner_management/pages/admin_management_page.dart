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
  int _section = 0;

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
      appBar: AppBar(
        title: const Text('Gestão do sistema'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              for (final item in const [
                ('Visão geral', Icons.dashboard_outlined),
                ('Aprovações', Icons.approval_outlined),
                ('Taxas e planos', Icons.payments_outlined),
                ('Funcionalidades', Icons.extension_outlined),
                ('Parceiros', Icons.business_outlined),
                ('Clientes', Icons.people_outline),
              ])
                Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: ChoiceChip(
                  selected: _section == const [
                    'Visão geral', 'Aprovações', 'Taxas e planos', 'Funcionalidades', 'Parceiros', 'Clientes'
                  ].indexOf(item.$1),
                  avatar: Icon(item.$2, size: 18),
                  label: Text(item.$1),
                  onSelected: (_) => setState(() => _section = const [
                    'Visão geral', 'Aprovações', 'Taxas e planos', 'Funcionalidades', 'Parceiros', 'Clientes'
                  ].indexOf(item.$1)),
                )),
            ]),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _sectionContent(),
              ),
/*                  const Card(
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
                ],*/
            ),
    );
  }

  List<Widget> _sectionContent() {
    switch (_section) {
      case 1:
        return [const Text('Aprovações', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 8), ..._operatorRequestCards()];
      case 2:
        return [const Text('Taxas e planos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 8), ..._fees.map((fee) => Card(child: ListTile(title: Text(fee['service_type'] as String? ?? ''), subtitle: Text('${fee['percentage'] ?? 0}% + BRL ${fee['fixed_amount'] ?? 0}'), trailing: const Icon(Icons.edit_outlined), onTap: () => _editFee(fee))))];
      case 3:
        return [const Text('Funcionalidades pagas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Card(child: ListTile(leading: Icon(Icons.analytics_outlined), title: Text('Indicadores avançados'), subtitle: Text('Habilite ou desabilite por parceiro após contratação.'))), const Card(child: ListTile(leading: Icon(Icons.account_balance_outlined), title: Text('Gestão financeira'), subtitle: Text('Controle de acesso ao módulo financeiro por plano.'))), const Card(child: ListTile(leading: Icon(Icons.groups_outlined), title: Text('Operadores adicionais'), subtitle: Text('Solicitações aprovadas ampliam o limite da empresa.')))];
      case 4:
        return [const Text('Parceiros', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 8), _overviewCard('Empresas parceiras', '${_overview['partners'] ?? 0}', Icons.business), _overviewCard('Unidades de estacionamento', '${_overview['parkings'] ?? 0}', Icons.local_parking), const Card(child: ListTile(title: Text('Serviços e funcionalidades'), subtitle: Text('Cada parceiro poderá ter serviços e funcionalidades liberados individualmente.')))];
      case 5:
        return [const Text('Clientes do app', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 8), _overviewCard('Clientes cadastrados', '${_overview['customers'] ?? 0}', Icons.people_outline), const Card(child: ListTile(title: Text('Usuários dos parceiros'), subtitle: Text('Consulte clientes que utilizam reservas e serviços da plataforma.')))];
      default:
        final cities = (_overview['cities'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
        final categories = (_overview['partner_categories'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        return [_overviewCard('Empresas', '${_overview['companies'] ?? 0}', Icons.apartment), _overviewCard('Unidades', '${_overview['parkings'] ?? 0}', Icons.local_parking), _overviewCard('Clientes', '${_overview['customers'] ?? 0}', Icons.person), _overviewCard('Parceiros', '${_overview['partners'] ?? 0}', Icons.business_center), const SizedBox(height: 8), const Text('Categorias de parceiros', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), for (final entry in categories.entries) Card(child: ListTile(leading: const Icon(Icons.category_outlined), title: Text(_categoryLabel(entry.key)), trailing: Text('${entry.value}'))), const SizedBox(height: 8), const Text('Cidades com serviços ativos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), if (cities.isEmpty) const Card(child: ListTile(title: Text('Nenhuma cidade cadastrada.'))) else for (final city in cities) Card(child: ListTile(leading: const Icon(Icons.location_on_outlined), title: Text(city['city'] as String? ?? ''), subtitle: Text('${city['active_parkings'] ?? 0} estacionamentos ativos · ${city['parkings'] ?? 0} unidades')),), const Card(child: ListTile(title: Text('Auditoria'), subtitle: Text('Próximo bloco: histórico de ações de usuários e administradores.')))];
    }
  }

  Widget _overviewCard(String title, String value, IconData icon) => Card(child: ListTile(leading: Icon(icon), title: Text(title), trailing: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))));
  String _categoryLabel(String value) => {'parking': 'Estacionamentos', 'tour_guide': 'Guias turísticos', 'car_wash': 'Lava-jatos', 'hotel': 'Hotéis', 'restaurant': 'Restaurantes', 'tourism_company': 'Empresas de turismo', 'transport': 'Transportes'}[value] ?? value;

  List<Widget> _operatorRequestCards() => _operatorRequests.isEmpty ? [const Card(child: ListTile(title: Text('Nenhuma solicitação pendente.')))] : [for (final request in _operatorRequests) Card(child: ListTile(title: Text('${request['quantity']} operador(es) · ${request['package_type']}'), subtitle: Text('${request['status']} · empresa ${request['tenant_id']}'), trailing: request['status'] == 'pending_review' ? Wrap(children: [IconButton(onPressed: () => _reviewOperatorRequest(request['id'] as String, 'approve'), icon: const Icon(Icons.check, color: Colors.green)), IconButton(onPressed: () => _reviewOperatorRequest(request['id'] as String, 'reject'), icon: const Icon(Icons.close, color: Colors.red))]) : null))];

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
