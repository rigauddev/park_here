import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../account/pages/account_setup_page.dart';
import '../../account/pages/vehicles_page.dart';
import '../../account/pages/wallet_page.dart';
import '../../reservation/pages/reservation_page.dart';
import '../models/auth_state.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart';

enum _MfaPreference { email, phone, authenticator }

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  String phone = '(71) 98888-7777';
  _MfaPreference mfaPreference = _MfaPreference.email;
  Uint8List? avatarBytes;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final email = auth.userEmail ?? 'cliente@parkhere.test';
    final isPartner = auth.accountType == AuthAccountType.partner;
    final isCustomer = auth.accountType == AuthAccountType.customer;
    final isMobileLayout = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.softCyan,
                    foregroundColor: AppTheme.primary,
                    backgroundImage: avatarBytes != null
                        ? MemoryImage(avatarBytes!)
                        : null,
                    child: avatarBytes == null
                        ? Icon(isPartner ? Icons.storefront : Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPartner ? 'Parceiro ParkHere' : 'Cliente ParkHere',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          email,
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Alterar foto',
                    onPressed: _pickAvatar,
                    icon: const Icon(Icons.photo_camera_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ReadonlySection(
            title: 'Dados da conta',
            rows: [('E-mail', email), ('Telefone', phone)],
          ),
          if (isCustomer) ...[
            const SizedBox(height: 14),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: const Text('Minha carteira'),
                    subtitle: const Text('Cartões, Pix e forma de pagamento'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WalletPage()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Minhas reservas'),
                    subtitle: const Text('Reservas, serviços e pré-reservas'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReservationPage()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.local_car_wash_outlined),
                    title: const Text('Serviços'),
                    subtitle: const Text('Filtros por estacionamento e serviços'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReservationPage()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.directions_car_filled_outlined),
                    title: const Text('Veículos'),
                    subtitle: const Text('Gerenciar placa, modelo e veiculo ativo'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VehiclesPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Completar cadastro'),
                  subtitle: const Text('Documentos e informações pessoais'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AccountSetupPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone_android),
                  title: const Text('Trocar telefone'),
                  subtitle: const Text('Validação por SMS obrigatória'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changePhone,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.password),
                  title: const Text('Alterar senha'),
                  subtitle: const Text('Use uma senha forte. Ex: Rig@ud2026'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changePassword,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MFA', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  RadioGroup<_MfaPreference>(
                    groupValue: mfaPreference,
                    onChanged: _setMfaPreference,
                    child: Column(
                      children: [
                        RadioListTile<_MfaPreference>(
                          value: _MfaPreference.email,
                          title: const Text('E-mail'),
                          subtitle: Text(email),
                        ),
                        RadioListTile<_MfaPreference>(
                          value: _MfaPreference.phone,
                          title: const Text('Telefone'),
                          subtitle: Text(phone),
                        ),
                        const RadioListTile<_MfaPreference>(
                          value: _MfaPreference.authenticator,
                          title: Text('Aplicativo autenticador'),
                          subtitle: Text(
                            'Google Authenticator, Authy ou similar',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMobileLayout) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sair'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _changePhone() async {
    final controller = TextEditingController(text: phone);
    final codeController = TextEditingController();
    String? pendingPhone;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final codeSent = pendingPhone != null;

            return AlertDialog(
              title: const Text('Trocar telefone'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    enabled: !codeSent,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Novo telefone',
                    ),
                  ),
                  if (codeSent) ...[
                    const SizedBox(height: 12),
                    const Text('Codigo SMS de teste: 000000'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Codigo SMS',
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                if (!codeSent)
                  FilledButton(
                    onPressed: () {
                      final nextPhone = controller.text.trim();
                      if (nextPhone.isEmpty) return;
                      setDialogState(() => pendingPhone = nextPhone);
                    },
                    child: const Text('Enviar SMS'),
                  )
                else
                  FilledButton(
                    onPressed: () {
                      if (codeController.text.trim() == '000000') {
                        Navigator.pop(context, pendingPhone);
                      }
                    },
                    child: const Text('Validar'),
                  ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    codeController.dispose();
    if (result == null || result.isEmpty) return;
    setState(() => phone = result);
  }

  void _setMfaPreference(_MfaPreference? value) {
    if (value == null) return;
    setState(() => mfaPreference = value);
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() => avatarBytes = bytes);
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    String? errorMessage;
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Alterar senha'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha atual'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Nova senha'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar senha',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Minimo 8 caracteres, maiuscula, minuscula e caractere especial. Ex: Rig@ud2026',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final password = passwordController.text;
                    if (currentController.text.isEmpty) {
                      setDialogState(
                        () => errorMessage = 'Informe a senha atual.',
                      );
                      return;
                    }
                    if (!_isStrongPassword(password)) {
                      setDialogState(
                        () => errorMessage =
                            'A nova senha nao atende aos requisitos.',
                      );
                      return;
                    }
                    if (password != confirmController.text) {
                      setDialogState(
                        () => errorMessage = 'As senhas nao coincidem.',
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    currentController.dispose();
    passwordController.dispose();
    confirmController.dispose();

    if (changed != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Senha alterada com sucesso.')),
    );
  }

  bool _isStrongPassword(String password) {
    final hasMinLength = password.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
    return hasMinLength && hasUpper && hasLower && hasSpecial;
  }
}

class _ReadonlySection extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;

  const _ReadonlySection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.$1,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        row.$2,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
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
}
