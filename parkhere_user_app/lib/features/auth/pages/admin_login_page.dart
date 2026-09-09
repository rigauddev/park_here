import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_state.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/main_navigation.dart';

class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});

  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final mfa = TextEditingController();
  bool obscure = true;
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    mfa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final mfaStep = auth.status == AuthStatus.mfaRequired;
    return Scaffold(
      backgroundColor: const Color(0xFF07152F),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                elevation: 18,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Image.asset('assets/branding/logo_rigaud_tech_clean.png', height: 58),
                    const SizedBox(height: 18),
                    const Text('Gestão do sistema', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF102657))),
                    const SizedBox(height: 4),
                    const Text('Rigaud Tech · ParkHere', textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF55708F))),
                    const SizedBox(height: 24),
                    if (!mfaStep) ...[
                      TextField(controller: email, keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'E-mail administrativo', prefixIcon: Icon(Icons.mail_outline))),
                      const SizedBox(height: 12),
                      TextField(controller: password, obscureText: obscure,
                        decoration: InputDecoration(labelText: 'Senha', prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => obscure = !obscure)))),
                    ] else
                      TextField(controller: mfa, keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Código MFA', prefixIcon: Icon(Icons.verified_user_outlined))),
                    const SizedBox(height: 20),
                    FilledButton.icon(onPressed: loading ? null : _submit,
                      icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
                      label: Text(mfaStep ? 'Validar acesso' : 'Entrar na gestão')),
                    TextButton(onPressed: loading ? null : () => Navigator.pop(context), child: const Text('Voltar ao ParkHere')),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => loading = true);
    try {
      final auth = ref.read(authProvider);
      if (auth.status == AuthStatus.mfaRequired) {
        await ref.read(authProvider.notifier).verifyMfa(mfa.text.trim());
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
            (_) => false,
          );
        }
      } else {
        await ref.read(authProvider.notifier).login(email.text.trim(), password.text, accountType: AuthAccountType.partner);
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}
