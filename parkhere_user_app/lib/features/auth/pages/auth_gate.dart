import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/main_navigation.dart';

import '../models/auth_state.dart';

import '../providers/auth_provider.dart';
import 'login_page.dart';
import '../../../core/widgets/app_loading.dart';
import 'admin_login_page.dart';
import 'partner_pending_page.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    // Acesso administrativo somente pela rota interna /admin. O link não é
    // exposto na tela pública do cliente.
    if (Uri.base.path == '/admin' && auth.status != AuthStatus.authenticated) {
      return const AdminLoginPage();
    }

    if (auth.status == AuthStatus.initial ||
        auth.status == AuthStatus.loading) {
      return Scaffold(
        body: AppLoading(partner: auth.accountType == AuthAccountType.partner),
      );
    }

    if (auth.status == AuthStatus.authenticated) {
      return const MainNavigation();
    }

    if (auth.status == AuthStatus.partnerPending) {
      return const PartnerPendingPage();
    }

    return const LoginPage();
  }
}
