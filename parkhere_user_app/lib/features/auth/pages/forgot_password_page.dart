import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'reset_password_page.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final emailController = TextEditingController();
  final codeController = TextEditingController();
  String? resetToken;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final codeRequested = resetToken != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      codeRequested
                          ? 'Digite o codigo recebido'
                          : 'Informe seu e-mail',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'O acesso fica bloqueado ate voce cadastrar uma nova senha.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: emailController,
                      enabled: !codeRequested,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail cadastrado',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    if (codeRequested) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Codigo',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isLoading
                            ? null
                            : codeRequested
                            ? _verifyCode
                            : _requestCode,
                        child: Text(
                          codeRequested ? 'Validar codigo' : 'Enviar codigo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestCode() async {
    if (emailController.text.trim().isEmpty) {
      _showError('Informe o e-mail cadastrado.');
      return;
    }

    setState(() => isLoading = true);
    try {
      final token = await ref
          .read(authProvider.notifier)
          .requestPasswordReset(emailController.text);
      if (!mounted) return;
      setState(() => resetToken = token);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Codigo enviado para o e-mail.')),
      );
    } catch (_) {
      _showError('Nao foi possivel enviar o codigo.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final token = resetToken;
    if (token == null || codeController.text.trim().isEmpty) {
      _showError('Informe o codigo.');
      return;
    }

    setState(() => isLoading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .verifyPasswordResetCode(token, codeController.text.trim());
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordPage(
            resetToken: token,
            code: codeController.text.trim(),
          ),
        ),
      );
    } catch (_) {
      _showError('Codigo invalido ou expirado.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
