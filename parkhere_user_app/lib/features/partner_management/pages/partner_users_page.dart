import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/validators/form_validators.dart';
import '../../../core/widgets/api_feedback.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/partner_operator_model.dart';
import '../models/managed_parking_model.dart';
import '../providers/partner_operators_provider.dart';
import '../providers/partner_parking_provider.dart';

const _operatorPermissionLabels = {
  'cash.view': 'Visualizar caixa e movimentações',
  'cash.manage': 'Abrir e fechar caixa e turno',
  'parking_map.view': 'Visualizar pátio de vagas',
  'parking_map.edit': 'Bloquear e liberar vagas',
  'reservations.view': 'Visualizar reservas',
  'reservations.create': 'Criar reservas operacionais',
  'reservations.edit': 'Editar reservas',
  'reservations.delete': 'Excluir/cancelar reservas',
  'reservations.cancel_own': 'Cancelar reserva criada por ele',
  'checkin.own': 'Realizar check-in de veículos',
  'checkout.own': 'Realizar checkout de veículos',
  'payments.receive': 'Receber pagamentos no local',
  'convenience.view': 'Visualizar conveniência',
  'convenience.sell': 'Operar PDV e caixa da conveniência',
  'convenience.edit': 'Cadastrar e editar produtos',
  'convenience.delete': 'Excluir produtos',
};

class _PermissionItem {
  final String key;
  final String label;
  final String actionType; // Ver, Criar, Editar, Excluir, Operar

  const _PermissionItem(this.key, this.label, this.actionType);
}

class _PermissionModule {
  final String name;
  final IconData icon;
  final List<_PermissionItem> items;

  const _PermissionModule({
    required this.name,
    required this.icon,
    required this.items,
  });
}

const _permissionModules = [
  _PermissionModule(
    name: 'Reservas & Pré-reservas',
    icon: Icons.calendar_today_outlined,
    items: [
      _PermissionItem('reservations.view', 'Ver reservas recebidas', 'Ver'),
      _PermissionItem('reservations.create', 'Criar reserva manual', 'Criar'),
      _PermissionItem('reservations.edit', 'Editar dados de reservas', 'Editar'),
      _PermissionItem('reservations.delete', 'Excluir / cancelar reservas', 'Excluir'),
      _PermissionItem('checkin.own', 'Realizar check-in de veículos', 'Operar'),
      _PermissionItem('checkout.own', 'Realizar checkout de veículos', 'Operar'),
    ],
  ),
  _PermissionModule(
    name: 'Pátio de Vagas (Mapa)',
    icon: Icons.local_parking_outlined,
    items: [
      _PermissionItem('parking_map.view', 'Ver mapa e ocupação de vagas', 'Ver'),
      _PermissionItem('parking_map.edit', 'Bloquear e liberar vagas', 'Editar'),
    ],
  ),
  _PermissionModule(
    name: 'Turno & Caixa',
    icon: Icons.point_of_sale_outlined,
    items: [
      _PermissionItem('cash.view', 'Ver saldo e movimentações do turno', 'Ver'),
      _PermissionItem('cash.manage', 'Abrir e fechar caixa / turno', 'Operar'),
    ],
  ),
  _PermissionModule(
    name: 'Pagamentos no Local',
    icon: Icons.payments_outlined,
    items: [
      _PermissionItem('payments.receive', 'Receber pagamentos (Dinheiro, Cartão, Pix)', 'Operar'),
    ],
  ),
  _PermissionModule(
    name: 'Conveniência & Loja',
    icon: Icons.storefront_outlined,
    items: [
      _PermissionItem('convenience.view', 'Ver catálogo e estoque da loja', 'Ver'),
      _PermissionItem('convenience.sell', 'Operar caixa e PDV da loja', 'Operar'),
      _PermissionItem('convenience.edit', 'Cadastrar e editar produtos', 'Editar'),
      _PermissionItem('convenience.delete', 'Excluir produtos do catálogo', 'Excluir'),
    ],
  ),
];

class PartnerUsersPage extends ConsumerWidget {
  const PartnerUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operators = ref.watch(partnerOperatorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          IconButton(
            tooltip: 'Regras e perfis',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _PermissionProfilesDialog(ref: ref),
            ),
            icon: const Icon(Icons.rule_outlined),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () => ref.invalidate(partnerOperatorsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateOperator(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Operador'),
      ),
      body: operators.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erro: $error'),
          ),
        ),
        data: (items) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _LimitCard(
                count: items.length,
                onRequest: () => _openPackageRequest(context, ref),
              ),
              const SizedBox(height: 14),
              if (items.isEmpty)
                const Center(child: Text('Nenhum operador cadastrado.'))
              else
                for (final operator in items)
                  _OperatorCard(
                    operator: operator,
                    onConfigure: () => _openAssignment(context, ref, operator),
                  ),
            ],
          );
        },
      ),
    );
  }

  void _openCreateOperator(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => _CreateOperatorDialog(ref: ref),
    );
  }

  void _openAssignment(
    BuildContext context,
    WidgetRef ref,
    PartnerOperatorModel operator,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _OperatorAssignmentDialog(operator: operator, ref: ref),
    );
  }

  void _openPackageRequest(BuildContext context, WidgetRef ref) {
    final quantity = TextEditingController(text: '1');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adicionar operadores'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'O limite incluído foi atingido. Solicite operadores adicionais e envie o comprovante para aprovação da gestão.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade de operadores',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final value = int.tryParse(quantity.text) ?? 0;
              if (value < 1) return;
              try {
                await ref
                    .read(partnerOperatorsProvider.notifier)
                    .requestOperatorPackage(
                      quantity: value,
                      packageType: value == 1 ? 'individual' : 'package',
                    );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Solicitação enviada. Aguarde a aprovação da gestão.',
                      ),
                    ),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  await ApiFeedback.show(context, '$error');
                }
              }
            },
            child: const Text('Solicitar'),
          ),
        ],
      ),
    );
  }
}

class _PermissionProfilesDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _PermissionProfilesDialog({required this.ref});
  @override
  ConsumerState<_PermissionProfilesDialog> createState() => _PermissionProfilesDialogState();
}

class _PermissionProfilesDialogState extends ConsumerState<_PermissionProfilesDialog> {
  List<Map<String, dynamic>> profiles = [];
  final selected = <String>{..._operatorPermissionLabels.keys};
  bool loading = true;
  bool creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = ref.read(authProvider).accessToken;
      if (token == null) throw Exception('Sessão expirada');
      final data = await ApiService().getAuthorized('/partners/permission-profiles', token);
      if (mounted) setState(() => profiles = data.cast<Map<String, dynamic>>());
    } catch (error) {
      if (mounted) await ApiFeedback.show(context, '$error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo perfil de regras'),
        content: TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome do perfil')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, name.text.trim()), child: const Text('Continuar')),
        ],
      ),
    );
    name.dispose();
    if (value == null || value.isEmpty) return;
    setState(() => creating = true);
    try {
      final token = ref.read(authProvider).accessToken;
      if (token == null) throw Exception('Sessão expirada');
      await ApiService().postAuthorized('/partners/permission-profiles', {
        'name': value,
        'permissions': selected.toList(),
      }, token);
      await _load();
    } catch (error) {
      if (mounted) await ApiFeedback.show(context, '$error');
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Regras e perfis de acesso'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Gestor pode criar perfis personalizados e associá-los aos operadores na configuração do usuário.'),
          const SizedBox(height: 12),
          if (loading) const Center(child: CircularProgressIndicator())
          else ...profiles.map((profile) => ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(profile['name']?.toString() ?? ''),
            subtitle: Text('${(profile['permissions'] as List<dynamic>? ?? []).length} permissões'),
          )),
          const Divider(),
          const Text('Permissões do novo perfil', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final entry in _operatorPermissionLabels.entries)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: selected.contains(entry.key),
              title: Text(entry.value),
              onChanged: (value) => setState(() => value == true ? selected.add(entry.key) : selected.remove(entry.key)),
            ),
        ]),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
      FilledButton.icon(onPressed: creating ? null : _create, icon: const Icon(Icons.add), label: const Text('Criar perfil')),
    ],
  );
}

class _LimitCard extends StatelessWidget {
  final int count;
  final VoidCallback onRequest;

  const _LimitCard({required this.count, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.softCyan,
                  foregroundColor: AppTheme.primary,
                  child: Icon(Icons.group_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$count de 2 operadores incluidos. Acima disso, sera cobrada taxa adicional.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onRequest,
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Solicitar operadores'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperatorCard extends StatelessWidget {
  final PartnerOperatorModel operator;
  final VoidCallback onConfigure;

  const _OperatorCard({required this.operator, required this.onConfigure});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppTheme.softCyan,
          foregroundColor: AppTheme.primary,
          child: Icon(Icons.badge_outlined),
        ),
        title: Text(operator.name),
        subtitle: Text(
          '${operator.email}\n${operator.phone ?? "Sem telefone"}',
        ),
        isThreeLine: true,
        onTap: onConfigure,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(operator.isActive ? 'Ativo' : 'Inativo'),
              backgroundColor: operator.isActive
                  ? AppTheme.success.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              side: BorderSide.none,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.manage_accounts_outlined, color: AppTheme.primary),
              tooltip: 'Gerenciar acessos e permissões',
              onPressed: onConfigure,
            ),
          ],
        ),
      ),
    );
  }
}

class _OperatorAssignmentDialog extends ConsumerStatefulWidget {
  final PartnerOperatorModel operator;
  final WidgetRef ref;
  const _OperatorAssignmentDialog({required this.operator, required this.ref});
  @override
  ConsumerState<_OperatorAssignmentDialog> createState() =>
      _OperatorAssignmentDialogState();
}

class _OperatorAssignmentDialogState
    extends ConsumerState<_OperatorAssignmentDialog> {
  final selected = <String>{};
  final selectedPermissions = <String>{};
  List<Map<String, dynamic>> profiles = [];
  String? selectedProfileId;
  bool loadingAssignments = true;
  bool savingAssignments = false;

  @override
  void initState() {
    super.initState();
    selectedPermissions.addAll(
      widget.operator.permissions.isNotEmpty
          ? widget.operator.permissions
          : _operatorPermissionLabels.keys,
    );
    _loadAssignments();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      final token = ref.read(authProvider).accessToken;
      if (token == null) return;
      final data = await ApiService().getAuthorized('/partners/permission-profiles', token);
      if (!mounted) return;
      final rows = data.cast<Map<String, dynamic>>();
      final matches = rows.where((profile) {
        final permissions = (profile['permissions'] as List<dynamic>? ?? []).cast<String>();
        return permissions.toSet().difference(selectedPermissions).isEmpty &&
            permissions.length == selectedPermissions.length;
      }).toList();
      setState(() { profiles = rows; selectedProfileId = matches.isEmpty ? null : matches.first['id'] as String?; });
    } catch (_) {}
  }

  Future<void> _loadAssignments() async {
    try {
      final ids = await ref
          .read(partnerOperatorsProvider.notifier)
          .fetchOperatorParkings(widget.operator.id);
      if (!mounted) return;
      setState(() {
        selected.addAll(ids);
        loadingAssignments = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loadingAssignments = false);
      await ApiFeedback.show(
        context,
        'Não foi possível carregar as unidades: $error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parkings = ref
        .watch(partnerParkingProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => <ManagedParkingModel>[],
        );
    return AlertDialog(
      title: Text('Dados do operador · ${widget.operator.name}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _readOnlyField('E-mail', widget.operator.email),
              _readOnlyField('CPF', widget.operator.cpf ?? 'Não informado'),
              _readOnlyField(
                'Telefone',
                widget.operator.phone ?? 'Não informado',
              ),
              _readOnlyField(
                'Situação',
                widget.operator.isActive ? 'Ativo' : 'Inativo',
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Unidades autorizadas',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (loadingAssignments)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!loadingAssignments && parkings.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Nenhuma unidade cadastrada.'),
                ),
              if (!loadingAssignments)
                for (final parking in parkings)
                  CheckboxListTile(
                    value: selected.contains(parking.id),
                    title: Text(parking.name),
                    onChanged: savingAssignments
                        ? null
                        : (value) => setState(
                            () => value == true
                                ? selected.add(parking.id!)
                                : selected.remove(parking.id),
                          ),
                    contentPadding: EdgeInsets.zero,
                  ),
              const Divider(),
              if (profiles.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  initialValue: selectedProfileId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Perfil de regras'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Permissões personalizadas')),
                    for (final profile in profiles.where((item) => item['id'] != null))
                      DropdownMenuItem<String?>(value: profile['id'] as String, child: Text(profile['name'].toString())),
                  ],
                  onChanged: savingAssignments ? null : (value) {
                    setState(() {
                      selectedProfileId = value;
                      if (value != null) {
                        final found = profiles.firstWhere((p) => p['id'] == value, orElse: () => {});
                        final list = (found['permissions'] as List<dynamic>? ?? []).cast<String>();
                        selectedPermissions.clear();
                        selectedPermissions.addAll(list);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],
              _PermissionMatrixWidget(
                selectedPermissions: selectedPermissions,
                enabled: !savingAssignments,
                onChanged: (newSet) {
                  setState(() {
                    selectedPermissions.clear();
                    selectedPermissions.addAll(newSet);
                    selectedProfileId = null;
                  });
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'O e-mail e o CPF são apenas para consulta. Os turnos são gerenciados na tela Escalas.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: savingAssignments ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: loadingAssignments || savingAssignments ? null : _save,
          icon: savingAssignments
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Salvar'),
        ),
      ],
    );
  }

  Widget _readOnlyField(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );

  Future<void> _save() async {
    setState(() => savingAssignments = true);
    try {
      await ref
          .read(partnerOperatorsProvider.notifier)
          .assignParkings(widget.operator.id, selected.toList());
      final token = ref.read(authProvider).accessToken;
      if (token != null) {
        await ApiService().putAuthorized('/partners/operators/${widget.operator.id}/permission-profile', {
          'profile_id': selectedProfileId,
          'permissions': selectedPermissions.toList(),
        }, token);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        await ApiFeedback.show(
          context,
          'Não foi possível salvar as unidades: $error',
        );
      }
    } finally {
      if (mounted) setState(() => savingAssignments = false);
    }
  }
}

class _CreateOperatorDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _CreateOperatorDialog({required this.ref});

  @override
  ConsumerState<_CreateOperatorDialog> createState() =>
      _CreateOperatorDialogState();
}

class _CreateOperatorDialogState extends ConsumerState<_CreateOperatorDialog> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final cpfController = TextEditingController();
  final passwordController = TextEditingController(text: 'Rig@ud2026');
  final selectedPermissions = <String>{..._operatorPermissionLabels.keys};
  bool acceptedTerms = false;
  bool isSaving = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    cpfController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo operador'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (value) =>
                      FormValidators.required(value, field: 'Nome'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  keyboardType: TextInputType.emailAddress,
                  validator: FormValidators.email,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                  keyboardType: TextInputType.phone,
                  validator: FormValidators.phoneBr,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: cpfController,
                  decoration: const InputDecoration(
                    labelText: 'CPF (opcional)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? null
                      : FormValidators.cpf(value),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha inicial'),
                  validator: FormValidators.password,
                ),
                const SizedBox(height: 14),
                _PermissionMatrixWidget(
                  selectedPermissions: selectedPermissions,
                  enabled: !isSaving,
                  onChanged: (newSet) {
                    setState(() {
                      selectedPermissions.clear();
                      selectedPermissions.addAll(newSet);
                    });
                  },
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: acceptedTerms,
                  onChanged: (value) =>
                      setState(() => acceptedTerms = value ?? false),
                  title: const Text('Aceito os termos de responsabilidade'),
                  subtitle: const Text(
                    'O operador tera apenas as permissoes selecionadas para atuar na empresa.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: isSaving ? null : _save,
          icon: isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_alt_1),
          label: const Text('Criar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    if (!acceptedTerms) {
      await _message('Aceite os termos para criar o operador.');
      return;
    }

    if (selectedPermissions.isEmpty) {
      await _message('Selecione ao menos uma permissao para o operador.');
      return;
    }

    setState(() => isSaving = true);
    try {
      await ref
          .read(partnerOperatorsProvider.notifier)
          .createOperator(
            name: nameController.text.trim(),
            email: emailController.text.trim(),
            phone: phoneController.text.trim(),
            cpf: cpfController.text.trim(),
            password: passwordController.text.trim(),
            acceptedTerms: acceptedTerms,
            permissions: selectedPermissions.toList()..sort(),
          );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      await _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _message(String text) async {
    await ApiFeedback.show(context, text);
  }
}

class _PermissionMatrixWidget extends StatelessWidget {
  final Set<String> selectedPermissions;
  final bool enabled;
  final ValueChanged<Set<String>> onChanged;

  const _PermissionMatrixWidget({
    required this.selectedPermissions,
    required this.enabled,
    required this.onChanged,
  });

  Color _badgeColor(String type) => switch (type) {
    'Ver' => Colors.blue.shade100,
    'Criar' => Colors.green.shade100,
    'Editar' => Colors.orange.shade100,
    'Excluir' => Colors.red.shade100,
    _ => Colors.purple.shade100,
  };

  Color _badgeTextColor(String type) => switch (type) {
    'Ver' => Colors.blue.shade900,
    'Criar' => Colors.green.shade900,
    'Editar' => Colors.orange.shade900,
    'Excluir' => Colors.red.shade900,
    _ => Colors.purple.shade900,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Permissões (Ver / Criar / Editar / Excluir)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: enabled
                      ? () => onChanged({..._operatorPermissionLabels.keys})
                      : null,
                  child: const Text('Todas', style: TextStyle(fontSize: 11)),
                ),
                TextButton(
                  onPressed: enabled
                      ? () {
                          final readOnlyKeys = <String>{};
                          for (final mod in _permissionModules) {
                            for (final item in mod.items) {
                              if (item.actionType == 'Ver') readOnlyKeys.add(item.key);
                            }
                          }
                          onChanged(readOnlyKeys);
                        }
                      : null,
                  child: const Text('Só Leitura', style: TextStyle(fontSize: 11)),
                ),
                TextButton(
                  onPressed: enabled ? () => onChanged({}) : null,
                  child: const Text('Limpar', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final module in _permissionModules) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              leading: Icon(module.icon, size: 20, color: AppTheme.primary),
              title: Text(
                module.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              subtitle: Text(
                '${module.items.where((i) => selectedPermissions.contains(i.key)).length} de ${module.items.length} liberadas',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              children: [
                for (final item in module.items)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: selectedPermissions.contains(item.key),
                    onChanged: enabled
                        ? (val) {
                            final updated = Set<String>.from(selectedPermissions);
                            if (val == true) {
                              updated.add(item.key);
                            } else {
                              updated.remove(item.key);
                            }
                            onChanged(updated);
                          }
                        : null,
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _badgeColor(item.actionType),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.actionType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _badgeTextColor(item.actionType),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(item.label, style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
