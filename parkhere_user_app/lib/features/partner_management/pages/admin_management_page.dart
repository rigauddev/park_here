import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/widgets/api_feedback.dart';

class AdminManagementPage extends ConsumerStatefulWidget {
  final int initialSection;
  const AdminManagementPage({super.key, this.initialSection = 0});

  @override
  ConsumerState<AdminManagementPage> createState() =>
      _AdminManagementPageState();
}

class _EmailPreviewBlock extends StatelessWidget {
  final String html;
  final Color background;

  const _EmailPreviewBlock({
    required this.html,
    this.background = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Text(
        _emailHtmlAsText(html),
        style: const TextStyle(color: Color(0xFF243047), height: 1.45),
      ),
    );
  }
}

String _emailHtmlAsText(String html) {
  return html
      .replaceAll(
        RegExp(r'<(script|style)\b[^>]*>[\s\S]*?</\1>', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</\s*(p|div|h[1-6]|li|tr)\s*>', caseSensitive: false),
        '\n\n',
      )
      .replaceAll(RegExp(r'<\s*li\b[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}

class _AdminManagementPageState extends ConsumerState<AdminManagementPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _fees = [];
  Map<String, dynamic> _overview = {};
  List<Map<String, dynamic>> _operatorRequests = [];
  List<Map<String, dynamic>> _featureRequests = [];
  List<Map<String, dynamic>> _partners = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _emailTemplates = [];
  List<Map<String, dynamic>> _featureRows = [];
  String? _featureTenantId;
  bool _featureLoading = false;
  String? _loadError;
  bool _loading = true;
  int _section = 0;
  final _partnerSearch = TextEditingController();
  final _customerSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection.clamp(0, 6).toInt();
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
        'Solicitações de funcionalidades',
        () =>
            _api.getAuthorized('/admin/platform-fees/feature-requests', token),
      ),
      safe(
        'Parceiros',
        () => _api.getAuthorized('/admin/platform-fees/partners', token),
      ),
      safe(
        'Clientes',
        () => _api.getAuthorized('/admin/platform-fees/customers', token),
      ),
      safe(
        'Templates',
        () => _api.getAuthorized('/admin/platform-fees/email-templates', token),
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
        _featureRequests = (values[3] as List).cast<Map<String, dynamic>>();
      }
      if (values[4] != null) {
        _partners = (values[4] as List).cast<Map<String, dynamic>>();
      }
      if (values[5] != null) {
        _customers = (values[5] as List).cast<Map<String, dynamic>>();
      }
      if (values[6] != null) {
        _emailTemplates = (values[6] as List).cast<Map<String, dynamic>>();
      }
      if (_featureTenantId == null && _partners.isNotEmpty) {
        _featureTenantId = _partners.first['tenant_id'] as String?;
      }
      _loadError = errors.isEmpty ? null : errors.join('\n');
      _loading = false;
    });
    if (_section == 3 && _featureTenantId != null) {
      await _loadPartnerFeatures(_featureTenantId!);
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
            child: Row(
              children: [
                for (final item in const [
                  ('Visão geral', Icons.dashboard_outlined),
                  ('Aprovações', Icons.approval_outlined),
                  ('Taxas e planos', Icons.payments_outlined),
                  ('Funcionalidades', Icons.extension_outlined),
                  ('Parceiros', Icons.business_outlined),
                  ('Clientes', Icons.people_outline),
                  ('Templates', Icons.mark_email_read_outlined),
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
                            'Templates',
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
                          'Templates',
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
          const SizedBox(height: 20),
          const Text(
            'Aprovação de parceiros',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._partnerApprovalCards(),
          const SizedBox(height: 20),
          const Text(
            'Solicitações de funcionalidades e capacidade',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._featureRequestCards(),
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
        return _partnerFeatureManager();
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
      case 6:
        return _emailTemplateSection();
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

  List<Widget> _partnerApprovalCards() {
    final pending = _partners
        .where((partner) => partner['approval_status'] != 'approved')
        .toList();
    if (pending.isEmpty) {
      return [const Card(child: ListTile(title: Text('Nenhum parceiro pendente.')))];
    }
    return [
      for (final partner in pending)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                partner['company_name'] as String? ?? 'Parceiro',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text('Status: ${partner['approval_status'] ?? 'pendente'}'),
              const SizedBox(height: 8),
              ...((partner['documents'] as List?) ?? const []).map(
                (item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(item['file_name'] as String? ?? 'Documento'),
                  subtitle: Text(item['document_type'] as String? ?? ''),
                  trailing: const Icon(Icons.visibility_outlined),
                  onTap: () => _showPartnerDocument(item),
                ),
              ),
              Wrap(spacing: 8, children: [
                if (partner['approval_status'] == 'documents_submitted' ||
                    partner['approval_status'] == 'waiting_documents')
                  FilledButton.tonal(
                    onPressed: () => _reviewPartnerApproval(
                      partner, 'documents', 'approve',
                    ),
                    child: const Text('Aprovar documentação'),
                  ),
                if (partner['approval_status'] == 'waiting_inspection')
                  FilledButton(
                    onPressed: () => _reviewPartnerApproval(
                      partner, 'inspection', 'approve',
                    ),
                    child: const Text('Aprovar vistoria'),
                  ),
                OutlinedButton(
                  onPressed: () => _reviewPartnerApproval(
                    partner,
                    partner['approval_status'] == 'waiting_inspection'
                        ? 'inspection'
                        : 'documents',
                    'reject',
                  ),
                  child: const Text('Reprovar'),
                ),
              ]),
            ]),
          ),
        ),
    ];
  }

  Future<void> _showPartnerDocument(Map<String, dynamic> document) async {
    final token = ref.read(authProvider).accessToken;
    final path = document['download_path'] as String?;
    if (token == null || path == null) return;
    try {
      final bytes = await _api.getAuthorizedBytes(path, token);
      if (!mounted) return;
      final fileName = document['file_name'] as String? ?? 'Documento';
      final extension = fileName.toLowerCase().split('.').last;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(fileName),
          content: SizedBox(
            width: 560,
            height: 480,
            child: extension == 'png' || extension == 'jpg' || extension == 'jpeg'
                ? InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain))
                : _PdfDocumentPreview(bytes: bytes),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
          ],
        ),
      );
    } catch (error) {
      if (mounted) await ApiFeedback.show(context, '$error');
    }
  }

  Future<void> _reviewPartnerApproval(
    Map<String, dynamic> partner,
    String stage,
    String decision,
  ) async {
    final token = ref.read(authProvider).accessToken;
    final tenantId = partner['tenant_id'] as String?;
    if (token == null || tenantId == null) return;
    try {
      await _api.patchAuthorized(
        '/admin/platform-fees/partners/$tenantId/approval',
        {'stage': stage, 'decision': decision},
        token,
      );
      await _load();
      if (mounted) {
        await ApiFeedback.show(context, decision == 'approve'
            ? 'Etapa aprovada.'
            : 'Parceiro reprovado.');
      }
    } catch (error) {
      if (mounted) await ApiFeedback.show(context, '$error');
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
                trailing: Wrap(
                  children: [
                    if (request['has_receipt'] == true)
                      IconButton(
                        tooltip: 'Visualizar comprovante',
                        onPressed: () => _viewOperatorPackageReceipt(
                          request['id'] as String,
                        ),
                        icon: const Icon(Icons.receipt_long_outlined),
                      ),
                    if (request['status'] == 'pending_review') ...[
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
                  ],
                ),
              ),
            ),
        ];

  Future<void> _viewFeatureReceipt(String requestId) async {
    await _viewReceipt(
      '/admin/platform-fees/feature-requests/$requestId/receipt',
    );
  }

  Future<void> _viewOperatorPackageReceipt(String requestId) async {
    await _viewReceipt(
      '/admin/platform-fees/operator-packages/requests/$requestId/receipt',
    );
  }

  Future<void> _viewReceipt(String endpoint) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    try {
      final bytes = await _api.getAuthorizedBytes(endpoint, token);
      final isPng =
          bytes.length > 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e;
      final isJpeg = bytes.length > 2 && bytes[0] == 0xff && bytes[1] == 0xd8;
      if (isPng || isJpeg) {
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            build: (_) => pw.Center(child: pw.Image(pw.MemoryImage(bytes))),
          ),
        );
        await Printing.layoutPdf(onLayout: (_) => doc.save());
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      }
    } catch (error) {
      if (mounted) {
        await ApiFeedback.show(
          context,
          'Não foi possível abrir o comprovante: $error',
        );
      }
    }
  }

  List<Widget> _featureRequestCards() => _featureRequests.isEmpty
      ? [
          const Card(
            child: ListTile(
              title: Text('Nenhuma solicitação de funcionalidade.'),
            ),
          ),
        ]
      : [
          for (final request in _featureRequests)
            Card(
              child: ListTile(
                isThreeLine: true,
                leading: Icon(
                  request['status'] == 'pending_review'
                      ? Icons.lock_clock_outlined
                      : request['status'] == 'approved'
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                ),
                title: Text(
                  '${request['tenant_name'] ?? request['tenant_id']} · ${request['feature_name'] ?? request['feature_key']}',
                ),
                subtitle: Text(
                  '${request['requested_by'] ?? ''} · ${request['quantity']} item(ns) · '
                  'R\$ ${((request['total_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} '
                  '${request['billing_period'] == 'monthly'
                      ? '/ mês'
                      : request['billing_period'] == 'annual'
                      ? '/ ano'
                      : 'uma vez'}\n'
                  'Status: ${request['status']}'
                  '${request['payment_method'] == null ? '' : '\nPagamento: ${request['payment_method']} · comprovante ${request['has_receipt'] == true ? 'anexado' : 'pendente'}'}',
                ),
                trailing: Wrap(
                  children: [
                    if (request['has_receipt'] == true)
                      IconButton(
                        tooltip: 'Visualizar comprovante',
                        onPressed: () =>
                            _viewFeatureReceipt(request['id'] as String),
                        icon: const Icon(Icons.receipt_long_outlined),
                      ),
                    if (request['status'] == 'pending_review')
                      IconButton(
                        tooltip: 'Aprovar e liberar',
                        onPressed: () => _reviewFeatureRequest(
                          request['id'] as String,
                          'approve',
                        ),
                        icon: const Icon(Icons.check, color: Colors.green),
                      ),
                    if (request['status'] == 'pending_review')
                      IconButton(
                        tooltip: 'Recusar',
                        onPressed: () => _reviewFeatureRequest(
                          request['id'] as String,
                          'reject',
                        ),
                        icon: const Icon(Icons.close, color: Colors.red),
                      ),
                  ],
                ),
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _editOperatorCapacity(partner),
                        icon: const Icon(Icons.groups_outlined),
                        label: Text(_tr('Limite de usuários', 'User limit')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          final tenantId = partner['tenant_id'] as String;
                          setState(() {
                            _featureTenantId = tenantId;
                            _section = 3;
                            _featureLoading = true;
                          });
                          _loadPartnerFeatures(tenantId);
                        },
                        icon: const Icon(Icons.extension_outlined),
                        label: Text(_tr('Funcionalidades', 'Features')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _setPartnerActive(
                      partner,
                      partner['tenant_status'] == 'SUSPENDED',
                      dialogContext,
                    ),
                    icon: Icon(
                      partner['tenant_status'] == 'SUSPENDED'
                          ? Icons.play_circle_outline
                          : Icons.pause_circle_outline,
                    ),
                    label: Text(
                      partner['tenant_status'] == 'SUSPENDED'
                          ? _tr('Reativar parceiro', 'Reactivate partner')
                          : _tr('Desativar parceiro', 'Deactivate partner'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
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
                      '${unit['address'] ?? ''}, ${unit['city'] ?? ''} · ${unit['is_active'] == true ? 'Ativo' : 'Inativo'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _editPartnerUnit(
                      partner['tenant_id'] as String,
                      unit as Map<String, dynamic>,
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

  String _tr(String portuguese, String english) =>
      context.strings.isEnglish ? english : portuguese;

  String _billingPeriodLabel(String? value) => switch (value) {
    'annual' => _tr('ano', 'year'),
    'one_time' => _tr('pagamento único', 'one time'),
    _ => _tr('mês', 'month'),
  };

  List<Widget> _partnerFeatureManager() {
    Map<String, dynamic>? selected;
    for (final partner in _partners) {
      if (partner['tenant_id'] == _featureTenantId) {
        selected = partner;
        break;
      }
    }
    return [
      Text(
        _tr('Funcionalidades por parceiro', 'Partner features'),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _featureTenantId,
        decoration: InputDecoration(
          labelText: _tr('Parceiro', 'Partner'),
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final partner in _partners)
            DropdownMenuItem<String>(
              value: partner['tenant_id'] as String,
              child: Text(
                partner['company_name'] as String? ??
                    partner['tenant_name'] as String? ??
                    _tr('Parceiro', 'Partner'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (tenantId) {
          if (tenantId == null) return;
          setState(() {
            _featureTenantId = tenantId;
            _featureRows = [];
            _featureLoading = true;
          });
          _loadPartnerFeatures(tenantId);
        },
      ),
      const SizedBox(height: 8),
      if (selected != null)
        Text(
          '${_categoryLabel(selected['service_type'] as String? ?? '')} · ${selected['tenant_status'] ?? ''}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      if (_featureTenantId == null)
        Card(
          child: ListTile(
            title: Text(
              _tr('Nenhum parceiro cadastrado.', 'No partner registered.'),
            ),
          ),
        )
      else if (_featureLoading)
        Card(
          child: ListTile(
            leading: const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text(
              _tr('Carregando funcionalidades…', 'Loading features…'),
            ),
          ),
        )
      else if (_featureRows.isEmpty)
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(
              _tr(
                'Nenhuma funcionalidade compatível está disponível para este tipo de parceiro.',
                'No compatible features are available for this partner type.',
              ),
            ),
            subtitle: Text(
              _tr(
                'Configure aqui as funções incluídas ou pagas. A quantidade de operadores continua seguindo a regra de unidades e pacotes de usuários.',
                'Configure included or paid features here. Operator quantity continues to follow unit and user-package rules.',
              ),
            ),
          ),
        )
      else
        for (final feature in _featureRows)
          Card(
            child: ListTile(
              leading: Icon(
                feature['is_enabled'] == true
                    ? Icons.toggle_on_outlined
                    : Icons.toggle_off_outlined,
              ),
              title: Text(
                (context.strings.isEnglish
                            ? feature['name_en']
                            : feature['name'])
                        as String? ??
                    feature['key'] as String,
              ),
              subtitle: Text(
                '${context.strings.isEnglish ? feature['description_en'] ?? feature['description'] : feature['description'] ?? ''}\n'
                '${feature['is_paid'] == true ? _tr('Paga', 'Paid') : _tr('Sem cobrança adicional', 'No additional charge')} · '
                '${feature['is_paid'] == true ? 'R\$ ${(feature['price'] as num? ?? 0).toStringAsFixed(2)} / ${_billingPeriodLabel(feature['billing_period'] as String?)}' : _tr('Acesso incluído', 'Included access')}',
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 0,
                children: [
                  IconButton(
                    tooltip: _tr('Configurar preço', 'Configure price'),
                    onPressed: () => _editPartnerFeature(feature),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  Switch(
                    value: feature['is_enabled'] == true,
                    onChanged: (enabled) =>
                        _savePartnerFeature(feature, isEnabled: enabled),
                  ),
                ],
              ),
            ),
          ),
      const SizedBox(height: 8),
      Text(
        _tr(
          'O catálogo inclui as funções existentes em Minha empresa e extras por quantidade. A equipe pode definir preço, gratuidade e acesso por parceiro. A cobrança automática ainda não está integrada; a liberação de pedidos é manual.',
          'This catalog includes current Minha empresa features and quantity add-ons. Management can set price, free/paid status and access per partner. Automatic billing is not integrated; requests are manually reviewed.',
        ),
      ),
    ];
  }

  Future<void> _editOperatorCapacity(Map<String, dynamic> partner) async {
    final tenantId = partner['tenant_id'] as String?;
    final token = ref.read(authProvider).accessToken;
    if (tenantId == null || token == null) return;
    final input = TextEditingController(
      text:
          '${partner['operator_limit_override'] ?? partner['base_operator_limit'] ?? 2}',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('Usuários permitidos', 'Allowed users')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tr(
                'O total atual é ${partner['operator_limit'] ?? 2}: base ${partner['base_operator_limit'] ?? 2} + ${partner['approved_extra_operators'] ?? 0} usuário(s) de pacotes aprovados. O valor abaixo ajusta somente a base; pacotes aprovados continuam somados.',
                'Current total is ${partner['operator_limit'] ?? 2}: base ${partner['base_operator_limit'] ?? 2} + ${partner['approved_extra_operators'] ?? 0} approved package user(s). The value below changes only the base; approved packages remain added.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: input,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _tr('Número de operadores', 'Operator count'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_tr('Cancelar', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_tr('Salvar', 'Save')),
          ),
        ],
      ),
    );
    if (saved == true) {
      final value = int.tryParse(input.text.trim());
      if (value == null || value < 0) {
        if (mounted) {
          await ApiFeedback.show(
            context,
            _tr('Informe um número válido.', 'Enter a valid number.'),
          );
        }
      } else {
        try {
          await _api.putAuthorized(
            '/admin/platform-fees/partners/$tenantId/operator-capacity',
            {'operator_limit': value},
            token,
          );
          await _load();
        } catch (error) {
          if (mounted) {
            await ApiFeedback.show(context, 'Limite: $error');
          }
        }
      }
    }
    input.dispose();
  }

  Future<void> _setPartnerActive(
    Map<String, dynamic> partner,
    bool active,
    BuildContext dialogContext,
  ) async {
    final tenantId = partner['tenant_id'] as String?;
    final token = ref.read(authProvider).accessToken;
    if (tenantId == null || token == null) return;
    final reasonController = TextEditingController();
    String? reason;
    if (!active) {
      reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_tr('Desativar parceiro', 'Deactivate partner')),
          content: TextField(
            controller: reasonController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: _tr(
                'Motivo (enviado por e-mail)',
                'Reason (emailed to partner)',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_tr('Cancelar', 'Cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, reasonController.text.trim()),
              child: Text(_tr('Desativar', 'Deactivate')),
            ),
          ],
        ),
      );
      if (reason == null || reason.trim().length < 5) {
        reasonController.dispose();
        return;
      }
    }
    try {
      await _api.patchAuthorized(
        '/admin/platform-fees/partners/$tenantId/status',
        {'is_active': active, if (!active) 'reason': reason},
        token,
      );
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      await _load();
    } catch (error) {
      if (mounted) {
        await ApiFeedback.show(context, 'Parceiro: $error');
      }
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _editPartnerUnit(
    String tenantId,
    Map<String, dynamic> unitSummary,
  ) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    Map<String, dynamic> unit;
    try {
      unit = await _api.getAuthorizedMap(
        '/admin/platform-fees/partners/$tenantId/units/${unitSummary['id']}',
        token,
      );
    } catch (error) {
      if (mounted) {
        await ApiFeedback.show(context, 'Unidade: $error');
      }
      return;
    }
    final name = TextEditingController(text: unit['name'] as String? ?? '');
    final address = TextEditingController(
      text: unit['address'] as String? ?? '',
    );
    final city = TextEditingController(text: unit['city'] as String? ?? '');
    final lat = TextEditingController(text: '${unit['lat'] ?? ''}');
    final lng = TextEditingController(text: '${unit['lng'] ?? ''}');
    if (!mounted) {
      name.dispose();
      address.dispose();
      city.dispose();
      lat.dispose();
      lng.dispose();
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(unit['name'] as String? ?? _tr('Unidade', 'Unit')),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: _tr('Nome da unidade', 'Unit name'),
                  ),
                ),
                TextField(
                  controller: address,
                  decoration: InputDecoration(
                    labelText: _tr('Endereço', 'Address'),
                  ),
                ),
                TextField(
                  controller: city,
                  decoration: InputDecoration(labelText: _tr('Cidade', 'City')),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: lat,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lng,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_tr('Vagas', 'Spots')}: ${unit['total_spots']} · ${_tr('Disponíveis', 'Available')}: ${unit['available_spots']}',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_tr('Fechar', 'Close')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'fees'),
            child: Text(_tr('Taxas da unidade', 'Unit fees')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: Text(_tr('Salvar dados', 'Save details')),
          ),
        ],
      ),
    );
    if (result == 'save') {
      try {
        await _api.patchAuthorized(
          '/admin/platform-fees/partners/$tenantId/units/${unit['id']}',
          {
            'name': name.text.trim(),
            'address': address.text.trim(),
            'city': city.text.trim(),
            'lat': double.tryParse(lat.text.replaceAll(',', '.')),
            'lng': double.tryParse(lng.text.replaceAll(',', '.')),
          },
          token,
        );
        await _load();
      } catch (error) {
        if (mounted) {
          await ApiFeedback.show(context, 'Dados da unidade: $error');
        }
      }
    } else if (result == 'fees') {
      await _editPartnerUnitFees(tenantId, unit['id'] as String);
    }
    name.dispose();
    address.dispose();
    city.dispose();
    lat.dispose();
    lng.dispose();
  }

  Future<void> _editPartnerUnitFees(String tenantId, String parkingId) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    List<Map<String, dynamic>> rows;
    try {
      rows = (await _api.getAuthorized(
        '/admin/platform-fees/partners/$tenantId/units/$parkingId/fees',
        token,
      )).cast<Map<String, dynamic>>();
    } catch (error) {
      if (mounted) {
        await ApiFeedback.show(context, 'Taxas da unidade: $error');
      }
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _tr('Taxas do app nesta unidade', 'App fees for this unit'),
        ),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                _tr(
                  'A configuração da unidade prevalece sobre a taxa do parceiro, que prevalece sobre o padrão global.',
                  'Unit settings override partner rates, which override global defaults.',
                ),
              ),
              for (final fee in rows)
                ListTile(
                  title: Text(
                    _categoryLabel(fee['service_type'] as String? ?? ''),
                  ),
                  subtitle: Text(
                    '${fee['source']} · ${fee['percentage']}% + R\$ ${fee['fixed_amount']}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final changed = await _editUnitFee(
                        tenantId,
                        parkingId,
                        fee,
                      );
                      if (changed && dialogContext.mounted) {
                        // Re-open with fresh effective values after save.
                        Navigator.pop(dialogContext);
                        if (mounted) {
                          await _editPartnerUnitFees(tenantId, parkingId);
                        }
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_tr('Fechar', 'Close')),
          ),
        ],
      ),
    );
  }

  Future<bool> _editUnitFee(
    String tenantId,
    String parkingId,
    Map<String, dynamic> fee,
  ) async {
    final percentage = TextEditingController(text: '${fee['percentage'] ?? 0}');
    final fixed = TextEditingController(text: '${fee['fixed_amount'] ?? 0}');
    var active = fee['is_active'] == true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            '${_tr('Taxa da unidade', 'Unit fee')}: ${_categoryLabel(fee['service_type'] as String? ?? '')}',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: percentage,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _tr('Percentual (%)', 'Percentage (%)'),
                ),
              ),
              TextField(
                controller: fixed,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _tr('Valor fixo (R\$)', 'Fixed amount (BRL)'),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_tr('Taxa ativa', 'Fee active')),
                value: active,
                onChanged: (value) => setDialogState(() => active = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_tr('Cancelar', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_tr('Salvar', 'Save')),
            ),
          ],
        ),
      ),
    );
    if (saved != true) {
      percentage.dispose();
      fixed.dispose();
      return false;
    }
    final token = ref.read(authProvider).accessToken;
    if (token == null) {
      percentage.dispose();
      fixed.dispose();
      return false;
    }
    try {
      await _api.putAuthorized(
        '/admin/platform-fees/partners/$tenantId/units/$parkingId/fees/${fee['service_type']}',
        {
          'service_type': fee['service_type'],
          'fee_mode': fee['fee_mode'] ?? 'hybrid',
          'fixed_amount': double.tryParse(fixed.text.replaceAll(',', '.')) ?? 0,
          'percentage':
              double.tryParse(percentage.text.replaceAll(',', '.')) ?? 0,
          'min_fee': fee['min_fee'] ?? 0,
          'max_fee': fee['max_fee'],
          'is_active': active,
        },
        token,
      );
      return true;
    } finally {
      percentage.dispose();
      fixed.dispose();
    }
  }

  Future<void> _loadPartnerFeatures(String tenantId) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    if (mounted) setState(() => _featureLoading = true);
    try {
      final rows = (await _api.getAuthorized(
        '/admin/platform-fees/partners/$tenantId/features',
        token,
      )).cast<Map<String, dynamic>>();
      if (mounted && tenantId == _featureTenantId) {
        setState(() {
          _featureRows = rows;
          _featureLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _featureLoading = false);
        await ApiFeedback.show(context, 'Funcionalidades: $error');
      }
    }
  }

  Future<void> _savePartnerFeature(
    Map<String, dynamic> feature, {
    bool? isEnabled,
    bool? isPaid,
    double? price,
    String? billingPeriod,
    Map<String, double>? billingPrices,
  }) async {
    final tenantId = _featureTenantId;
    final token = ref.read(authProvider).accessToken;
    if (tenantId == null || token == null) return;
    try {
      await _api.putAuthorized(
        '/admin/platform-fees/partners/$tenantId/features/${feature['key']}',
        {
          'is_enabled': isEnabled ?? feature['is_enabled'] == true,
          'is_paid': isPaid ?? feature['is_paid'] == true,
          'price': price ?? (feature['price'] as num? ?? 0).toDouble(),
          'billing_prices': billingPrices ?? feature['billing_prices'] ?? {},
          'billing_period':
              billingPeriod ?? feature['billing_period'] ?? 'monthly',
          'notes': feature['notes'],
        },
        token,
      );
      await _loadPartnerFeatures(tenantId);
    } catch (error) {
      if (mounted) {
        await ApiFeedback.show(context, 'Não foi possível salvar: $error');
      }
    }
  }

  Future<void> _editPartnerFeature(Map<String, dynamic> feature) async {
    var enabled = feature['is_enabled'] == true;
    var paid = feature['is_paid'] == true;
    var period = feature['billing_period'] as String? ?? 'monthly';
    final prices = (feature['billing_prices'] as Map<String, dynamic>?) ?? {};
    final monthly = TextEditingController(
      text:
          '${prices['monthly'] ?? (period == 'monthly' ? feature['price'] : 0) ?? 0}'
              .replaceAll('.', ','),
    );
    final annual = TextEditingController(
      text:
          '${prices['annual'] ?? (period == 'annual' ? feature['price'] : 0) ?? 0}'
              .replaceAll('.', ','),
    );
    final oneTime = TextEditingController(
      text:
          '${prices['one_time'] ?? (period == 'one_time' ? feature['price'] : 0) ?? 0}'
              .replaceAll('.', ','),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(feature['name'] as String? ?? feature['key'] as String),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _tr('Ativa para o parceiro', 'Enabled for partner'),
                    ),
                    value: enabled,
                    onChanged: (value) => setDialogState(() => enabled = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_tr('Funcionalidade paga', 'Paid feature')),
                    value: paid,
                    onChanged: (value) => setDialogState(() => paid = value),
                  ),
                  TextField(
                    controller: monthly,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _tr(
                        'Preço mensal recorrente (BRL)',
                        'Monthly recurring price (BRL)',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: annual,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _tr('Preço anual (BRL)', 'Annual price (BRL)'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: oneTime,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _tr(
                        'Pagamento único · 30 dias (BRL)',
                        'One-time · 30 days (BRL)',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: period,
                    decoration: InputDecoration(
                      labelText: _tr('Cobrança', 'Billing period'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text(_tr('Mensal', 'Monthly')),
                      ),
                      DropdownMenuItem(
                        value: 'annual',
                        child: Text(_tr('Anual', 'Annual')),
                      ),
                      DropdownMenuItem(
                        value: 'one_time',
                        child: Text(_tr('Única', 'One time')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => period = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_tr('Cancelar', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_tr('Salvar', 'Save')),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _savePartnerFeature(
        feature,
        isEnabled: enabled,
        isPaid: paid,
        price: switch (period) {
          'annual' => double.tryParse(annual.text.replaceAll(',', '.')) ?? 0,
          'one_time' => double.tryParse(oneTime.text.replaceAll(',', '.')) ?? 0,
          _ => double.tryParse(monthly.text.replaceAll(',', '.')) ?? 0,
        },
        billingPeriod: period,
        billingPrices: {
          'monthly': double.tryParse(monthly.text.replaceAll(',', '.')) ?? 0,
          'annual': double.tryParse(annual.text.replaceAll(',', '.')) ?? 0,
          'one_time': double.tryParse(oneTime.text.replaceAll(',', '.')) ?? 0,
        },
      );
    }
    monthly.dispose();
    annual.dispose();
    oneTime.dispose();
  }

  List<Widget> _emailTemplateSection() => [
    Text(
      _tr('Templates de e-mail', 'Email templates'),
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 8),
    Text(
      _tr(
        'Edite assunto, cabeçalho, conteúdo e rodapé. O cabeçalho inclui a logo ParkHere; variáveis disponíveis: {{name}}, {{code}}, {{reason}}, {{company}}.',
        'Edit the subject, header, body and footer. The header includes the ParkHere logo. Available variables: {{name}}, {{code}}, {{reason}}, {{company}}.',
      ),
    ),
    const SizedBox(height: 8),
    if (_emailTemplates.isEmpty)
      Card(
        child: ListTile(
          title: Text(
            _tr('Nenhum template retornado.', 'No templates returned.'),
          ),
        ),
      )
    else
      for (final template in _emailTemplates)
        Card(
          child: ListTile(
            leading: const Icon(Icons.mark_email_read_outlined),
            title: Text(
              template['display_name'] as String? ??
                  template['template_key'] as String,
            ),
            subtitle: Text('${template['locale']} · ${template['subject']}'),
            trailing: Icon(
              template['is_active'] == true
                  ? Icons.check_circle_outline
                  : Icons.pause_circle_outline,
            ),
            onTap: () => _editEmailTemplate(template),
          ),
        ),
  ];

  Future<void> _editEmailTemplate(Map<String, dynamic> template) async {
    final name = TextEditingController(
      text: template['display_name'] as String? ?? '',
    );
    final subject = TextEditingController(
      text: template['subject'] as String? ?? '',
    );
    final header = TextEditingController(
      text: template['header_html'] as String? ?? '',
    );
    final body = TextEditingController(
      text: template['body_html'] as String? ?? '',
    );
    final footer = TextEditingController(
      text: template['footer_html'] as String? ?? '',
    );
    var active = template['is_active'] == true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${template['display_name']} · ${template['locale']}'),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: InputDecoration(labelText: _tr('Nome', 'Name')),
                  ),
                  TextField(
                    controller: subject,
                    decoration: InputDecoration(
                      labelText: _tr('Assunto', 'Subject'),
                    ),
                  ),
                  TextField(
                    controller: header,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: _tr('HTML do cabeçalho', 'Header HTML'),
                    ),
                  ),
                  TextField(
                    controller: body,
                    minLines: 5,
                    maxLines: 12,
                    decoration: InputDecoration(
                      labelText: _tr('HTML do corpo', 'Body HTML'),
                    ),
                  ),
                  TextField(
                    controller: footer,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: _tr('HTML do rodapé', 'Footer HTML'),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_tr('Template ativo', 'Template active')),
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => _previewEmailTemplate(
                context,
                name: name.text,
                subject: subject.text,
                locale: template['locale'] as String? ?? 'pt_BR',
                headerHtml: header.text,
                bodyHtml: body.text,
                footerHtml: footer.text,
              ),
              icon: const Icon(Icons.visibility_outlined),
              label: Text(_tr('Visualizar', 'Preview')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_tr('Cancelar', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_tr('Salvar', 'Save')),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final token = ref.read(authProvider).accessToken;
      if (token != null) {
        try {
          await _api.putAuthorized(
            '/admin/platform-fees/email-templates/${template['template_key']}/${template['locale']}',
            {
              'display_name': name.text,
              'subject': subject.text,
              'header_html': header.text,
              'body_html': body.text,
              'footer_html': footer.text,
              'is_active': active,
            },
            token,
          );
          await _load();
        } catch (error) {
          if (mounted) {
            await ApiFeedback.show(context, 'Template: $error');
          }
        }
      }
    }
    name.dispose();
    subject.dispose();
    header.dispose();
    body.dispose();
    footer.dispose();
  }

  Future<void> _previewEmailTemplate(
    BuildContext context, {
    required String name,
    required String subject,
    required String locale,
    required String headerHtml,
    required String bodyHtml,
    required String footerHtml,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (previewContext) => AlertDialog(
        title: Text(_tr('Prévia do e-mail', 'Email preview')),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE3E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          '$name · $locale',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          subject,
                          style: const TextStyle(
                            color: Color(0xFF101B4D),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const Divider(height: 24),
                      if (headerHtml.trim().isNotEmpty)
                        _EmailPreviewBlock(
                          html: headerHtml,
                          background: const Color(0xFFF4F8FF),
                        ),
                      _EmailPreviewBlock(html: bodyHtml),
                      if (footerHtml.trim().isNotEmpty)
                        _EmailPreviewBlock(
                          html: footerHtml,
                          background: const Color(0xFFF8FAFC),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(previewContext),
            child: Text(_tr('Fechar prévia', 'Close preview')),
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
        await ApiFeedback.show(
          context,
          active ? 'Serviço ativado.' : 'Serviço desativado.',
          isError: false,
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        await ApiFeedback.show(
          context,
          'Não foi possível atualizar o serviço: $error',
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
        await ApiFeedback.show(
          context,
          'Não foi possível carregar as taxas do parceiro: $error',
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
      await ApiFeedback.show(
        context,
        'Taxa individual salva; ela substitui a taxa padrão para este parceiro.',
        isError: false,
      );
    }
  }

  Future<void> _setUserActive(Map<String, dynamic> user, bool active) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    String? reason;
    if (!active) {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_tr('Desativar usuário', 'Deactivate user')),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: _tr(
                'Motivo (será enviado por e-mail)',
                'Reason (sent by email)',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_tr('Cancelar', 'Cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(_tr('Desativar', 'Deactivate')),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null || reason.trim().length < 5) return;
    }
    try {
      await _api.patchAuthorized(
        '/admin/platform-fees/users/${user['id']}/status',
        {'is_active': active, if (!active) 'reason': reason},
        token,
      );
      if (mounted) {
        await ApiFeedback.show(
          context,
          active ? 'Acesso reativado.' : 'Acesso desativado.',
          isError: false,
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        await ApiFeedback.show(
          context,
          'Não foi possível atualizar o usuário: $error',
        );
      }
    }
  }

  Future<void> _reviewOperatorRequest(String id, String decision) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    try {
      await _api.postAuthorized(
        '/admin/platform-fees/operator-packages/requests/$id/$decision',
        {},
        token,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        await ApiFeedback.show(
          context,
          'Não foi possível analisar o pedido: $error',
        );
      }
    }
  }

  Future<void> _reviewFeatureRequest(String id, String decision) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    try {
      await _api.putAuthorized(
        '/admin/platform-fees/feature-requests/$id/$decision',
        {},
        token,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        await ApiFeedback.show(
          context,
          'Não foi possível analisar a solicitação: $error',
        );
      }
    }
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

class _PdfDocumentPreview extends StatelessWidget {
  final Uint8List bytes;
  const _PdfDocumentPreview({required this.bytes});

  @override
  Widget build(BuildContext context) => PdfPreview(
        build: (_) async => bytes,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: false,
        allowSharing: false,
      );
}
