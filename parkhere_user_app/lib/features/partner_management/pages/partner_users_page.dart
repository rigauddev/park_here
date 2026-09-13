import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/validators/form_validators.dart';
import '../../../core/widgets/api_feedback.dart';
import '../models/partner_operator_model.dart';
import '../models/managed_parking_model.dart';
import '../providers/partner_operators_provider.dart';
import '../providers/partner_parking_provider.dart';

const _operatorPermissionLabels = {
  'reservations.view': 'Ver reservas',
  'parking_map.view': 'Patio de vagas',
  'reservations.create': 'Criar reserva',
  'reservations.cancel_own': 'Cancelar reserva criada por ele',
  'checkin.own': 'Check-in das reservas dele',
  'checkout.own': 'Checkout das reservas dele',
  'payments.receive': 'Receber pagamento',
};

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
        trailing: SizedBox(
          width: 160,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            runSpacing: 6,
            children: [
              Chip(
                label: Text(operator.isActive ? 'Ativo' : 'Inativo'),
                backgroundColor: operator.isActive
                    ? AppTheme.success.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                side: BorderSide.none,
              ),
              Chip(
                label: Text('${operator.permissions.length} permissoes'),
                side: BorderSide.none,
              ),
            ],
          ),
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
  bool loadingAssignments = true;
  bool savingAssignments = false;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
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
              const Text(
                'O e-mail e o CPF são apenas para consulta. Os turnos são gerenciados na tela Escalas.',
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Permissoes',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 6),
                for (final entry in _operatorPermissionLabels.entries)
                  CheckboxListTile(
                    value: selectedPermissions.contains(entry.key),
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          selectedPermissions.add(entry.key);
                        } else {
                          selectedPermissions.remove(entry.key);
                        }
                      });
                    },
                    title: Text(entry.value),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
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
