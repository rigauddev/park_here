import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';

class AdminManagementPage extends ConsumerStatefulWidget {
  final int initialSection;
  const AdminManagementPage({super.key, this.initialSection = 0});

  @override
  ConsumerState<AdminManagementPage> createState() =>
      _AdminManagementPageState();
}

class _AdminManagementPageState extends ConsumerState<AdminManagementPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _fees = [];
  Map<String, dynamic> _overview = {};
  List<Map<String, dynamic>> _operatorRequests = [];
  List<Map<String, dynamic>> _partners = [];
  List<Map<String, dynamic>> _customers = [];
  String? _loadError;
  bool _loading = true;
  int _section = 0;
  final _partnerSearch = TextEditingController();
  final _customerSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection.clamp(0, 5).toInt();
    _load();
  }

  @override
  void dispose() {
    _partnerSearch.dispose();
    _customerSearch.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) {
      if (mounted) {
        setState(() {
          _loadError =
              'Sessão administrativa ausente. Entre novamente em /admin.';
          _loading = false;
        });
      }
      return;
    }
    final errors = <String>[];
    Future<T?> safe<T>(String label, Future<T> Function() load) async {
      try {
        return await load();
      } catch (error) {
        errors.add('$label: $error');
        return null;
      }
    }

    final values = await Future.wait<Object?>([
      safe('Taxas', () => _api.getAuthorized('/admin/platform-fees', token)),
      safe(
        'Visão geral',
        () => _api.getAuthorizedMap('/admin/platform-fees/overview', token),
      ),
      safe(
        'Aprovações',
        () => _api.getAuthorized(
          '/admin/platform-fees/operator-packages/requests',
          token,
        ),
      ),
      safe(
        'Parceiros',
        () => _api.getAuthorized('/admin/platform-fees/partners', token),
      ),
      safe(
        'Clientes',
        () => _api.getAuthorized('/admin/platform-fees/customers', token),
      ),
    ]);
    if (!mounted) return;
    setState(() {
      if (values[0] != null) {
        _fees = (values[0] as List).cast<Map<String, dynamic>>();
      }
      if (values[1] != null) _overview = values[1] as Map<String, dynamic>;
      if (values[2] != null) {
        _operatorRequests = (values[2] as List).cast<Map<String, dynamic>>();
      }
      if (values[3] != null) {
        _partners = (values[3] as List).cast<Map<String, dynamic>>();
      }
      if (values[4] != null) {
        _customers = (values[4] as List).cast<Map<String, dynamic>>();
      }
      _loadError = errors.isEmpty ? null : errors.join('\n');
      _loading = false;
    });
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
            child: Row(
              children: [
                for (final item in const [
                  ('Visão geral', Icons.dashboard_outlined),
                  ('Aprovações', Icons.approval_outlined),
                  ('Taxas e planos', Icons.payments_outlined),
                  ('Funcionalidades', Icons.extension_outlined),
                  ('Parceiros', Icons.business_outlined),
                  ('Clientes', Icons.people_outline),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      selected:
                          _section ==
                          const [
                            'Visão geral',
                            'Aprovações',
                            'Taxas e planos',
                            'Funcionalidades',
                            'Parceiros',
                            'Clientes',
                          ].indexOf(item.$1),
                      avatar: Icon(item.$2, size: 18),
                      label: Text(item.$1),
                      onSelected: (_) => setState(
                        () => _section = const [
                          'Visão geral',
                          'Aprovações',
                          'Taxas e planos',
                          'Funcionalidades',
                          'Parceiros',
                          'Clientes',
                        ].indexOf(item.$1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_loadError != null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Algumas informações não carregaram:\n$_loadError',
                        ),
                      ),
                    ),
                  ..._sectionContent(),
                ],
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
        return [
          const Text(
            'Aprovações',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._operatorRequestCards(),
        ];
      case 2:
        return [
          const Text(
            'Taxas e planos',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._fees.map(
            (fee) => Card(
              child: ListTile(
                title: Text(fee['service_type'] as String? ?? ''),
                subtitle: Text(
                  '${fee['percentage'] ?? 0}% + BRL ${fee['fixed_amount'] ?? 0}',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editFee(fee),
              ),
            ),
          ),
        ];
      case 3:
        return [
          const Text(
            'Funcionalidades pagas',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.analytics_outlined),
              title: Text('Indicadores avançados'),
              subtitle: Text(
                'Habilite ou desabilite por parceiro após contratação.',
              ),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.account_balance_outlined),
              title: Text('Gestão financeira'),
              subtitle: Text(
                'Controle de acesso ao módulo financeiro por plano.',
              ),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.groups_outlined),
              title: Text('Operadores adicionais'),
              subtitle: Text(
                'Solicitações aprovadas ampliam o limite da empresa.',
              ),
            ),
          ),
        ];
      case 4:
        final search = _partnerSearch.text.trim().toLowerCase();
        final filtered = _partners
            .where(
              (partner) =>
                  search.isEmpty ||
                  '${partner['company_name']} ${partner['tenant_name']} ${partner['service_type']} ${partner['tenant_id']}'
                      .toLowerCase()
                      .contains(search),
            )
            .toList();
        return [
          const Text(
            'Parceiros',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('${_partners.length} empresas parceiras cadastradas'),
          const SizedBox(height: 8),
          TextField(
            controller: _partnerSearch,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar empresa, categoria ou ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (_partners.isEmpty)
            const Card(
              child: ListTile(
                title: Text(
                  'Nenhum parceiro retornado pela API. Use atualizar para tentar novamente.',
                ),
              ),
            )
          else if (filtered.isEmpty)
            const Card(
              child: ListTile(
                title: Text('Nenhum parceiro corresponde à busca.'),
              ),
            )
          else
            for (final partner in filtered)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.business),
                  title: Text(
                    partner['company_name'] as String? ??
                        partner['tenant_name'] as String? ??
                        'Empresa sem nome',
                  ),
                  subtitle: Text(
                    '${_categoryLabel(partner['service_type'] as String? ?? '')} · ${partner['operator_count'] ?? 0}/${partner['operator_limit'] ?? 0} operadores · ${partner['services_count'] ?? 0} serviços · ${(partner['parkings'] as List?)?.length ?? 0} unidades',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPartnerDetails(partner),
                ),
              ),
        ];
      case 5:
        final search = _customerSearch.text.trim().toLowerCase();
        final filtered = _customers
            .where(
              (customer) =>
                  search.isEmpty ||
                  '${customer['name']} ${customer['email']} ${customer['phone']}'
                      .toLowerCase()
                      .contains(search),
            )
            .toList();
        return [
          const Text(
            'Clientes do app',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _overviewCard(
            'Clientes cadastrados',
            '${_customers.length}',
            Icons.people_outline,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _customerSearch,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por nome, e-mail ou telefone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (_customers.isEmpty)
            const Card(
              child: ListTile(title: Text('Nenhum cliente encontrado.')),
            )
          else if (filtered.isEmpty)
            const Card(
              child: ListTile(
                title: Text('Nenhum cliente corresponde à busca.'),
              ),
            )
          else
            for (final customer in filtered)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(customer['name'] as String? ?? 'Sem nome'),
                  subtitle: Text(
                    '${customer['email'] ?? ''}\n${customer['phone'] ?? 'Sem telefone'}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Gerenciar cliente',
                    onSelected: (value) =>
                        _setUserActive(customer, value == 'activate'),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: customer['is_active'] == true
                            ? 'deactivate'
                            : 'activate',
                        child: Text(
                          customer['is_active'] == true
                              ? 'Desativar acesso'
                              : 'Reativar acesso',
                        ),
                      ),
                    ],
                    child: Icon(
                      customer['is_active'] == true
                          ? Icons.check_circle
                          : Icons.pause_circle,
                      color: customer['is_active'] == true
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ),
              ),
        ];
      default:
        final cities =
            (_overview['cities'] as List?)?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];
        final categories =
            (_overview['partner_categories'] as Map?)
                ?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        return [
          _overviewCard(
            'Empresas',
            '${_overview['companies'] ?? 0}',
            Icons.apartment,
          ),
          _overviewCard(
            'Unidades',
            '${_overview['parkings'] ?? 0}',
            Icons.local_parking,
          ),
          _overviewCard(
            'Clientes',
            '${_overview['customers'] ?? 0}',
            Icons.person,
          ),
          _overviewCard(
            'Parceiros',
            '${_overview['partners'] ?? 0}',
            Icons.business_center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Categorias de parceiros',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          for (final entry in categories.entries)
            Card(
              child: ListTile(
                leading: const Icon(Icons.category_outlined),
                title: Text(_categoryLabel(entry.key)),
                trailing: Text('${entry.value}'),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Cidades com serviços ativos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (cities.isEmpty)
            const Card(
              child: ListTile(title: Text('Nenhuma cidade cadastrada.')),
            )
          else
            for (final city in cities)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(city['city'] as String? ?? ''),
                  subtitle: Text(
                    '${city['active_parkings'] ?? 0} estacionamentos ativos · ${city['parkings'] ?? 0} unidades',
                  ),
                ),
              ),
          const Card(
            child: ListTile(
              title: Text('Auditoria'),
              subtitle: Text(
                'Próximo bloco: histórico de ações de usuários e administradores.',
              ),
            ),
          ),
        ];
    }
  }

  Widget _overviewCard(String title, String value, IconData icon) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Text(
        value,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    ),
  );
  String _categoryLabel(String value) =>
      {
        'parking': 'Estacionamentos',
        'tour_guide': 'Guias turísticos',
        'car_wash': 'Lava-jatos',
        'hotel': 'Hotéis',
        'restaurant': 'Restaurantes',
        'tourism_company': 'Empresas de turismo',
        'transport': 'Transportes',
      }[value] ??
      value;

  List<Widget> _operatorRequestCards() => _operatorRequests.isEmpty
      ? [
          const Card(
            child: ListTile(title: Text('Nenhuma solicitação pendente.')),
          ),
        ]
      : [
          for (final request in _operatorRequests)
            Card(
              child: ListTile(
                title: Text(
                  '${request['quantity']} operador(es) · ${request['package_type']}',
                ),
                subtitle: Text(
                  '${request['status']} · empresa ${request['tenant_id']}',
                ),
                trailing: request['status'] == 'pending_review'
                    ? Wrap(
                        children: [
                          IconButton(
                            onPressed: () => _reviewOperatorRequest(
                              request['id'] as String,
                              'approve',
                            ),
                            icon: const Icon(Icons.check, color: Colors.green),
                          ),
                          IconButton(
                            onPressed: () => _reviewOperatorRequest(
                              request['id'] as String,
                              'reject',
                            ),
                            icon: const Icon(Icons.close, color: Colors.red),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
        ];

  void _showPartnerDetails(Map<String, dynamic> partner) {
    final users = (partner['users'] as List?) ?? const [];
    final parkings = (partner['parkings'] as List?) ?? const [];
    final services = (partner['services'] as List?) ?? const [];
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          partner['company_name'] as String? ??
              partner['tenant_name'] as String? ??
              'Parceiro',
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Categoria: ${_categoryLabel(partner['service_type'] as String? ?? '')}',
                ),
                Text('Aprovação: ${partner['approval_status'] ?? 'pendente'}'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Usuários ${users.length}')),
                    Chip(
                      label: Text('Serviços ${partner['services_count'] ?? 0}'),
                    ),
                    Chip(label: Text('Unidades ${parkings.length}')),
                    Chip(
                      label: Text(
                        'Operadores ${partner['operator_count'] ?? 0}/${partner['operator_limit'] ?? 0}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Equipe',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final user in users)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(user['name'] as String? ?? ''),
                    subtitle: Text('${user['email'] ?? ''} · ${user['role']}'),
                    trailing: IconButton(
                      tooltip: user['is_active'] == true
                          ? 'Desativar usuário'
                          : 'Reativar usuário',
                      onPressed: () async {
                        await _setUserActive(
                          user as Map<String, dynamic>,
                          user['is_active'] != true,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      },
                      icon: Icon(
                        user['is_active'] == true
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Unidades',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final unit in parkings)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.store_outlined),
                    title: Text(unit['name'] as String? ?? ''),
                    subtitle: Text(
                      '${unit['city'] ?? ''} · ${unit['is_active'] == true ? 'Ativo' : 'Inativo'}',
                    ),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Serviços cadastrados',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (services.isEmpty)
                  const ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Nenhum serviço cadastrado.'),
                  )
                else
                  for (final service in services)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        service['is_active'] == true
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                      ),
                      title: Text(service['name'] as String? ?? ''),
                      subtitle: Text(
                        '${service['service_type'] == 'parking' ? service['unit_name'] ?? 'Estacionamento' : 'Guia turístico'} · R\$ ${service['price'] ?? 0} · ${service['is_active'] == true ? 'Ativo' : 'Inativo'}',
                      ),
                      trailing: IconButton(
                        tooltip: service['is_active'] == true
                            ? 'Desativar serviço'
                            : 'Ativar serviço',
                        icon: Icon(
                          service['is_active'] == true
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                        ),
                        onPressed: () => _setPartnerServiceActive(
                          partner['tenant_id'] as String,
                          service as Map<String, dynamic>,
                          service['is_active'] != true,
                          dialogContext,
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _managePartnerFees(partner),
                  icon: const Icon(Icons.percent),
                  label: const Text('Taxas individuais do parceiro'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _setPartnerServiceActive(
    String tenantId,
    Map<String, dynamic> service,
    bool active,
    BuildContext dialogContext,
  ) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    try {
      await _api.patchAuthorized(
        '/admin/platform-fees/partners/$tenantId/services/${service['service_type']}/${service['id']}/status',
        {'is_active': active},
        token,
      );
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(active ? 'Serviço ativado.' : 'Serviço desativado.'),
          ),
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível atualizar o serviço: $error'),
          ),
        );
      }
    }
  }

  Future<void> _managePartnerFees(Map<String, dynamic> partner) async {
    final tenantId = partner['tenant_id'] as String?;
    final token = ref.read(authProvider).accessToken;
    if (tenantId == null || token == null) return;
    try {
      final rows = (await _api.getAuthorized(
        '/admin/platform-fees/partners/$tenantId/fees',
        token,
      )).cast<Map<String, dynamic>>();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Taxas por parceiro'),
          content: SizedBox(
            width: 480,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  'As taxas globais são o padrão. Um valor individual substitui o padrão somente para este parceiro.',
                ),
                for (final fee in rows)
                  ListTile(
                    title: Text(
                      _categoryLabel(fee['service_type'] as String? ?? ''),
                    ),
                    subtitle: Text(
                      '${fee['source'] == 'partner' ? 'Personalizada' : 'Padrão'} · ${fee['percentage']}% + R\$ ${fee['fixed_amount']}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editPartnerFee(tenantId, fee),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Não foi possível carregar as taxas do parceiro: $error',
            ),
          ),
        );
      }
    }
  }

  Future<void> _editPartnerFee(
    String tenantId,
    Map<String, dynamic> fee,
  ) async {
    final percentage = TextEditingController(text: '${fee['percentage'] ?? 0}');
    final fixed = TextEditingController(text: '${fee['fixed_amount'] ?? 0}');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Taxa ${_categoryLabel(fee['service_type'] as String? ?? '')}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: percentage,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Percentual (%)'),
            ),
            TextField(
              controller: fixed,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Valor fixo (R\$)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (result != true) return;
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    await _api.putAuthorized(
      '/admin/platform-fees/partners/$tenantId/fees/${fee['service_type']}',
      {
        'service_type': fee['service_type'],
        'fee_mode': fee['fee_mode'] ?? 'hybrid',
        'fixed_amount': double.tryParse(fixed.text.replaceAll(',', '.')) ?? 0,
        'percentage':
            double.tryParse(percentage.text.replaceAll(',', '.')) ?? 0,
        'min_fee': fee['min_fee'] ?? 0,
        'max_fee': fee['max_fee'],
        'is_active': fee['is_active'] ?? true,
      },
      token,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Taxa individual salva; ela substitui a taxa padrão para este parceiro.',
          ),
        ),
      );
    }
  }

  Future<void> _setUserActive(Map<String, dynamic> user, bool active) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    try {
      await _api.patchAuthorized(
        '/admin/platform-fees/users/${user['id']}/status',
        {'is_active': active},
        token,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(active ? 'Acesso reativado.' : 'Acesso desativado.'),
          ),
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível atualizar o usuário: $error'),
          ),
        );
      }
    }
  }

  Future<void> _reviewOperatorRequest(String id, String decision) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    await _api.postAuthorized(
      '/admin/platform-fees/operator-packages/requests/$id/$decision',
      {},
      token,
    );
    await _load();
  }

  Future<void> _editFee(Map<String, dynamic> fee) async {
    final percentage = TextEditingController(text: '${fee['percentage'] ?? 0}');
    final fixed = TextEditingController(text: '${fee['fixed_amount'] ?? 0}');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Taxa: ${fee['service_type']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: percentage,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Percentual (%)'),
            ),
            TextField(
              controller: fixed,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Valor fixo (R\$)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
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
