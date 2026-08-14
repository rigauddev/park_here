import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/validators/form_validators.dart';
import '../models/partner_operator_model.dart';
import '../providers/partner_operators_provider.dart';

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
              _LimitCard(count: items.length),
              const SizedBox(height: 14),
              if (items.isEmpty)
                const Center(child: Text('Nenhum operador cadastrado.'))
              else
                for (final operator in items) _OperatorCard(operator: operator),
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
}

class _LimitCard extends StatelessWidget {
  final int count;

  const _LimitCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
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
      ),
    );
  }
}

class _OperatorCard extends StatelessWidget {
  final PartnerOperatorModel operator;

  const _OperatorCard({required this.operator});

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
  final passwordController = TextEditingController(text: 'Rig@ud2026');
  final selectedPermissions = <String>{..._operatorPermissionLabels.keys};
  bool acceptedTerms = false;
  bool isSaving = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
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
      _message('Aceite os termos para criar o operador.');
      return;
    }

    if (selectedPermissions.isEmpty) {
      _message('Selecione ao menos uma permissao para o operador.');
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
            password: passwordController.text.trim(),
            acceptedTerms: acceptedTerms,
            permissions: selectedPermissions.toList()..sort(),
          );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
