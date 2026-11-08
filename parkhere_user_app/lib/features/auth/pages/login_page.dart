import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_state.dart';
import '../providers/auth_provider.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/i18n/app_localizations.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import 'admin_login_page.dart';

enum LoginLanguage { ptBr, en }

enum LoginMode { customer, partner }

/// Entrada administrativa exposta apenas em builds internos/homologação.
const _showAdminEntry = bool.fromEnvironment(
  'PARKHERE_ADMIN_ENTRY',
  defaultValue: false,
);

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final mfaController = TextEditingController();

  bool isLoading = false;
  bool showPassword = false;
  LoginLanguage language = LoginLanguage.ptBr;
  LoginMode loginMode = LoginMode.customer;
  String? loginError;
  late final AnimationController _backgroundAnimation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  bool get isPortuguese => language == LoginLanguage.ptBr;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    mfaController.dispose();
    _backgroundAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    language = locale.languageCode == 'en'
        ? LoginLanguage.en
        : LoginLanguage.ptBr;
    final authState = ref.watch(authProvider);
    final isMfaStep = authState.status == AuthStatus.mfaRequired;
    final displayedLoginMode = isMfaStep
        ? (authState.accountType == AuthAccountType.partner
              ? LoginMode.partner
              : LoginMode.customer)
        : loginMode;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: loginMode == LoginMode.customer
                ? const [
                    Color(0xFF061A3C),
                    Color(0xFF0B2D61),
                    Color(0xFF1677FF),
                  ]
                : const [
                    Color(0xFF071633),
                    Color(0xFF123A70),
                    Color(0xFF19AFC8),
                  ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                child: AnimatedBuilder(
                  animation: _backgroundAnimation,
                  builder: (context, _) => CustomPaint(
                    key: ValueKey(loginMode),
                    painter: _LoginBackgroundPainter(
                      loginMode,
                      progress: _backgroundAnimation.value,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 18, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showAdminEntry)
                      TextButton.icon(
                        onPressed: isMfaStep
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminLoginPage(),
                                ),
                              ),
                        icon: const Icon(Icons.settings_outlined, size: 15),
                        label: Text(isPortuguese ? 'Gestão' : 'Admin'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: 0.72),
                          textStyle: const TextStyle(fontSize: 11),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 8),
                    _LanguageFlagButton(
                      language: language,
                      onChanged: (value) {
                        setState(() => language = value);
                        ref
                            .read(appLanguageProvider.notifier)
                            .setLanguage(
                              value == LoginLanguage.en
                                  ? const Locale('en')
                                  : const Locale('pt', 'BR'),
                            );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 1100) {
                    return const SizedBox.shrink();
                  }
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 64, right: 500),
                      child: _ServiceHubHero(isPortuguese: isPortuguese),
                    ),
                  );
                },
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1100;
                return Align(
                  alignment: isWide ? Alignment.centerRight : Alignment.center,
                  child: Padding(
                    padding: EdgeInsets.only(right: isWide ? 64 : 0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 28,
                                offset: Offset(0, 14),
                                color: Color(0x33000000),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _ServiceHubBrand(),
                                const SizedBox(height: 4),
                                Text(
                                  context.strings.loginTagline,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF55708F),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (!isMfaStep) ...[
                                  const SizedBox(height: 10),
                                  _AccessModeSelector(
                                    loginMode: displayedLoginMode,
                                    isPortuguese: isPortuguese,
                                    enabled: true,
                                    onChanged: (mode) {
                                      ref
                                          .read(authProvider.notifier)
                                          .resetLoginFlow();
                                      setState(() {
                                        loginMode = mode;
                                        loginError = null;
                                        mfaController.clear();
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _textField(
                                    controller: emailController,
                                    label: isPortuguese ? "E-mail" : "Email",
                                    icon: Icons.mail_outline,
                                  ),
                                  const SizedBox(height: 12),
                                  _textField(
                                    controller: passwordController,
                                    label: isPortuguese ? "Senha" : "Password",
                                    icon: Icons.lock_outline,
                                    obscureText: !showPassword,
                                    suffixIcon: IconButton(
                                      tooltip: showPassword
                                          ? (isPortuguese
                                                ? 'Ocultar senha'
                                                : 'Hide password')
                                          : (isPortuguese
                                                ? 'Mostrar senha'
                                                : 'Show password'),
                                      onPressed: () => setState(
                                        () => showPassword = !showPassword,
                                      ),
                                      icon: Icon(
                                        showPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF102657,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      onPressed: isLoading
                                          ? null
                                          : _submitLogin,
                                      child: isLoading
                                          ? const _LoginLoadingLabel()
                                          : Text(
                                              _loginButtonLabel(isPortuguese),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ForgotPasswordPage(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      isPortuguese
                                          ? "Esqueci minha senha"
                                          : "Forgot password",
                                      style: const TextStyle(
                                        color: Color(0xFF55708F),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => RegisterPage(
                                            initialType:
                                                loginMode == LoginMode.customer
                                                ? RegisterAccountType.customer
                                                : RegisterAccountType.partner,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      loginMode == LoginMode.customer
                                          ? (isPortuguese
                                                ? "Criar conta"
                                                : "Create account")
                                          : (isPortuguese
                                                ? "Cadastrar estabelecimento parceiro"
                                                : "Register partner business"),
                                      style: const TextStyle(
                                        color: Color(0xFF169FC4),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  // MFA STEP: Apenas os elementos de MFA são exibidos
                                  const SizedBox(height: 8),
                                  const CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Color(0xFFE8F6FA),
                                    foregroundColor: Color(0xFF169FC4),
                                    child: Icon(
                                      Icons.shield_outlined,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isPortuguese
                                        ? "Verificação em Duas Etapas (MFA)"
                                        : "Two-Factor Authentication",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF102657),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isPortuguese
                                        ? "Digite o código gerado pelo seu aplicativo autenticador para continuar."
                                        : "Enter the code generated by your authenticator app to proceed.",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF55708F),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _textField(
                                    controller: mfaController,
                                    label: isPortuguese
                                        ? "Código de verificação"
                                        : "Verification code",
                                    icon: Icons.verified_user_outlined,
                                  ),
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF169FC4,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      onPressed: isLoading
                                          ? null
                                          : _submitLogin,
                                      child: isLoading
                                          ? const _LoginLoadingLabel()
                                          : Text(
                                              isPortuguese
                                                  ? "Verificar código"
                                                  : "Verify code",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF55708F,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFD9E8F0),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      onPressed: isLoading
                                          ? null
                                          : () {
                                              emailController.clear();
                                              passwordController.clear();
                                              mfaController.clear();
                                              ref
                                                  .read(authProvider.notifier)
                                                  .resetLoginFlow();
                                            },
                                      icon: const Icon(
                                        Icons.arrow_back,
                                        size: 18,
                                      ),
                                      label: Text(
                                        isPortuguese
                                            ? 'Cancelar acesso e voltar'
                                            : 'Cancel access and return',
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (loginError != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(child: _LoginErrorBanner(message: loginError!)),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: Center(
                  child: _RigaudTechFooter(isPortuguese: isPortuguese),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF169FC4)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF7FBFD),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD9E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD9E8F0)),
        ),
      ),
    );
  }

  Future<void> _submitLogin() async {
    final authState = ref.read(authProvider);
    final isMfaAttempt = authState.status == AuthStatus.mfaRequired;

    setState(() {
      isLoading = true;
      loginError = null;
    });

    try {
      if (authState.status != AuthStatus.mfaRequired) {
        if (emailController.text.isEmpty || passwordController.text.isEmpty) {
          throw Exception(
            isPortuguese ? "Preencha todos os campos" : "Fill in all fields",
          );
        }

        await ref
            .read(authProvider.notifier)
            .login(
              emailController.text.trim(),
              passwordController.text.trim(),
              accountType: loginMode == LoginMode.customer
                  ? AuthAccountType.customer
                  : AuthAccountType.partner,
            );
      } else {
        if (mfaController.text.isEmpty) {
          throw Exception(
            isPortuguese ? "Digite o código MFA" : "Enter MFA code",
          );
        }

        await ref
            .read(authProvider.notifier)
            .verifyMfa(mfaController.text.trim());
      }
    } catch (e) {
      // Never leave secrets or an MFA challenge visible after a failed
      // authentication attempt. The user must start a fresh challenge.
      passwordController.clear();
      if (isMfaAttempt) {
        emailController.clear();
        mfaController.clear();
        ref.read(authProvider.notifier).resetLoginFlow();
      }
      if (!mounted) return;
      final message = _authErrorMessage(e);
      setState(() => loginError = message);
      Future<void>.delayed(const Duration(seconds: 4), () {
        if (!mounted || loginError != message) return;
        setState(() => loginError = null);
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _authErrorMessage(Object error) {
    final rawMessage = error.toString().replaceFirst("Exception: ", "");

    if (rawMessage == "Credenciais inválidas") {
      return isPortuguese ? "Credenciais inválidas" : "Invalid credentials";
    }

    return rawMessage;
  }

  String _loginButtonLabel(bool isPortuguese) {
    if (loginMode == LoginMode.partner) {
      return isPortuguese ? "Entrar como parceiro" : "Sign in as partner";
    }

    return isPortuguese ? "Entrar como cliente" : "Sign in as customer";
  }
}

class _ServiceHubHero extends StatelessWidget {
  final bool isPortuguese;

  const _ServiceHubHero({required this.isPortuguese});

  @override
  Widget build(BuildContext context) {
    final labels = isPortuguese
        ? const ['Estacionamento', 'Locação de veículos', 'Guia turístico']
        : const ['Parking', 'Car rental', 'Tour guide'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ServiceHubBrand(scale: 2.15),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0)
                Container(
                  height: 42,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              _ServiceFeature(
                icon: switch (i) {
                  0 => Icons.local_parking_outlined,
                  1 => Icons.directions_car_outlined,
                  _ => Icons.tour_outlined,
                },
                label: labels[i],
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ServiceFeature extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ServiceFeature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 110,
    child: Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _ServiceHubBrand extends StatelessWidget {
  final double scale;

  const _ServiceHubBrand({this.scale = 1});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SvgPicture.asset(
        'assets/branding/servicehub_icon_concept.svg',
        width: 62 * scale,
        height: 62 * scale,
      ),
      SizedBox(width: 10 * scale),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Service',
              style: TextStyle(color: Color(0xFF081A3A)),
            ),
            TextSpan(
              text: 'Hub',
              style: TextStyle(color: Color(0xFF1677FF)),
            ),
          ],
        ),
        style: TextStyle(
          fontSize: 34 * scale,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2 * scale,
        ),
      ),
    ],
  );
}

class _LoginErrorBanner extends StatelessWidget {
  final String message;

  const _LoginErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD32F2F)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFD32F2F)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFFD32F2F),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageFlagButton extends StatelessWidget {
  final LoginLanguage language;
  final ValueChanged<LoginLanguage> onChanged;

  const _LanguageFlagButton({required this.language, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final label = language == LoginLanguage.ptBr ? "PT-BR" : "EN";
    final flag = language == LoginLanguage.ptBr ? "🇧🇷" : "🇺🇸";

    return PopupMenuButton<LoginLanguage>(
      tooltip: "Idioma / Language",
      initialValue: language,
      onSelected: onChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: LoginLanguage.ptBr,
          child: Row(
            children: [
              Text('🇧🇷', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text('Português Brasil'),
            ],
          ),
        ),
        PopupMenuItem(
          value: LoginLanguage.en,
          child: Row(
            children: [
              Text('🇺🇸', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text('English'),
            ],
          ),
        ),
      ],
      child: Material(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF102657),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF102657),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RigaudTechFooter extends StatelessWidget {
  final bool isPortuguese;

  const _RigaudTechFooter({required this.isPortuguese});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _openRigaudTech,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.60),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isPortuguese ? "Desenvolvido por" : "Developed by",
                style: const TextStyle(
                  color: Color(0xFF55708F),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  "assets/branding/logo_rigaud_tech_clean.png",
                  width: 58,
                  height: 16,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRigaudTech() async {
    final uri = Uri.parse('https://rigaudtech.com.br');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _LoginLoadingLabel extends StatelessWidget {
  const _LoginLoadingLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          "assets/branding/logo_rigaud_tech_clean.png",
          width: 34,
          height: 16,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 10),
        const Text(
          'Entrando...',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _AccessModeSelector extends StatelessWidget {
  final LoginMode loginMode;
  final bool isPortuguese;
  final bool enabled;
  final ValueChanged<LoginMode> onChanged;

  const _AccessModeSelector({
    required this.loginMode,
    required this.isPortuguese,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAFBFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AccessModeButton(
              selected: loginMode == LoginMode.customer,
              icon: Icons.directions_car_filled_outlined,
              title: isPortuguese ? "Cliente" : "Customer",
              subtitle: isPortuguese ? "Reservar vaga" : "Book parking",
              onTap: enabled ? () => onChanged(LoginMode.customer) : null,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _AccessModeButton(
              selected: loginMode == LoginMode.partner,
              icon: Icons.storefront,
              title: isPortuguese ? "Parceiro" : "Partner",
              subtitle: isPortuguese ? "Gerir serviços" : "Manage services",
              onTap: enabled ? () => onChanged(LoginMode.partner) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessModeButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _AccessModeButton({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x1A102657),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected
                    ? const Color(0xFF169FC4)
                    : const Color(0xFF55708F),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF102657),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF55708F), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginBackgroundPainter extends CustomPainter {
  final LoginMode mode;
  final double progress;

  const _LoginBackgroundPainter(this.mode, {this.progress = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final mapOverlay = Paint()..color = const Color(0xB8051730);
    canvas.drawRect(Offset.zero & size, mapOverlay);

    final routePaint = Paint()
      ..color = const Color(0xFF44C8FF).withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8;
    final accentPaint = Paint()
      ..color = const Color(0xFF00D8FF).withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    if (mode == LoginMode.partner) {
      // Silhuetas discretas de painel: reforçam a operação sem competir com o login.
      final panelPaint = Paint()
        ..color = const Color(0xFFFFC66B).withValues(alpha: 0.13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (var i = 0; i < 3; i++) {
        final rect = Rect.fromLTWH(
          size.width * (0.06 + i * 0.34),
          size.height * (0.72 - i * 0.06),
          size.width * 0.24,
          size.height * 0.12,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(12)),
          panelPaint,
        );
        canvas.drawLine(
          Offset(rect.left + 12, rect.bottom - 12),
          Offset(rect.right - 12, rect.bottom - 12),
          panelPaint,
        );
        final barHeight =
            size.height *
            (0.025 + 0.035 * math.sin(progress * math.pi * 2 + i));
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left + 14,
            rect.top + 14,
            size.width * 0.035,
            rect.height * 0.55 + barHeight,
          ),
          Paint()..color = const Color(0xFFFFC66B).withValues(alpha: 0.26),
        );
      }
      final partnerGridPaint = Paint()
        ..color = const Color(0xFF8FC8F5).withValues(alpha: 0.09)
        ..strokeWidth = 1;
      for (var i = 1; i < 7; i++) {
        canvas.drawLine(
          Offset(size.width * i / 7, 0),
          Offset(size.width * i / 7, size.height),
          partnerGridPaint,
        );
        canvas.drawLine(
          Offset(0, size.height * i / 7),
          Offset(size.width, size.height * i / 7),
          partnerGridPaint,
        );
      }
    } else {
      // Grade leve de ruas para o modo cliente.
      final gridPaint = Paint()
        ..color = const Color(0xFF8FC8F5).withValues(alpha: 0.11)
        ..strokeWidth = 1;
      for (var i = 1; i < 7; i++) {
        canvas.drawLine(
          Offset(size.width * i / 7, 0),
          Offset(size.width * i / 7, size.height),
          gridPaint,
        );
        canvas.drawLine(
          Offset(0, size.height * i / 7),
          Offset(size.width, size.height * i / 7),
          gridPaint,
        );
      }

      // Quadras sutis para aproximar a textura de mapa da referência.
      final blockPaint = Paint()
        ..color = const Color(0xFF8FC8F5).withValues(alpha: 0.045)
        ..style = PaintingStyle.fill;
      for (var row = 0; row < 4; row++) {
        for (var column = 0; column < 6; column++) {
          final rect = Rect.fromLTWH(
            size.width * (column * 0.19 + 0.015),
            size.height * (row * 0.24 + 0.04),
            size.width * 0.15,
            size.height * 0.16,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(5)),
            blockPaint,
          );
        }
      }
    }

    final pulse = (math.sin(progress * math.pi * 2) + 1) / 2;
    final movingPoint = _routePoint(size, progress);
    canvas.drawCircle(
      movingPoint,
      14 + pulse * 8,
      Paint()..color = const Color(0xFF28D8FF).withValues(alpha: 0.14),
    );
    canvas.drawCircle(movingPoint, 6, Paint()..color = const Color(0xFFE9FCFF));

    _drawMovingVehicle(
      canvas,
      movingPoint,
      mode == LoginMode.customer ? Icons.directions_car : Icons.storefront,
      mode == LoginMode.customer ? 28 : 25,
    );

    final secondProgress = (progress + 0.52) % 1;
    _drawMovingVehicle(
      canvas,
      _routePoint(size, secondProgress),
      mode == LoginMode.customer ? Icons.two_wheeler : Icons.analytics_outlined,
      mode == LoginMode.customer ? 23 : 21,
    );

    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.25)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.08,
        size.width * 0.42,
        size.height * 0.34,
        size.width * 0.62,
        size.height * 0.18,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.05,
        size.width * 0.88,
        size.height * 0.35,
        size.width * 1.02,
        size.height * 0.2,
      );
    // Rota principal com brilho, semelhante ao mapa da referência.
    final routeGlow = Paint()
      ..color = const Color(0xFF08B7FF).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(path, routeGlow);
    canvas.drawPath(path, routePaint);

    final lowerPath = Path()
      ..moveTo(-20, size.height * 0.78)
      ..cubicTo(
        size.width * 0.20,
        size.height * 0.62,
        size.width * 0.38,
        size.height * 0.90,
        size.width * 0.58,
        size.height * 0.72,
      )
      ..cubicTo(
        size.width * 0.74,
        size.height * 0.56,
        size.width * 0.90,
        size.height * 0.83,
        size.width + 20,
        size.height * 0.68,
      );
    canvas.drawPath(lowerPath, accentPaint);

    // A origem e o destino permanecem discretos; o único elemento em
    // movimento é o veículo da rota, evitando poluir o card de autenticação.
    _drawPin(canvas, Offset(size.width * 0.05, size.height * 0.25), 14);
    _drawPin(canvas, Offset(size.width * 0.88, size.height * 0.30), 14);
  }

  Offset _routePoint(Size size, double t) {
    final start = Offset(size.width * 0.05, size.height * 0.25);
    final controlOne = Offset(size.width * 0.25, size.height * 0.08);
    final controlTwo = Offset(size.width * 0.62, size.height * 0.18);
    final end = Offset(size.width * 0.88, size.height * 0.30);
    final u = 1 - t;
    return Offset(
      u * u * u * start.dx +
          3 * u * u * t * controlOne.dx +
          3 * u * t * t * controlTwo.dx +
          t * t * t * end.dx,
      u * u * u * start.dy +
          3 * u * u * t * controlOne.dy +
          3 * u * t * t * controlTwo.dy +
          t * t * t * end.dy,
    );
  }

  void _drawPin(Canvas canvas, Offset center, double size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.25);
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: size * 0.48))
      ..moveTo(center.dx, center.dy + size * 0.84)
      ..lineTo(center.dx - size * 0.30, center.dy + size * 0.25)
      ..lineTo(center.dx + size * 0.30, center.dy + size * 0.25)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawMovingVehicle(
    Canvas canvas,
    Offset center,
    IconData icon,
    double size,
  ) {
    canvas.drawCircle(
      center,
      size * 0.82,
      Paint()..color = const Color(0xFF071A3A).withValues(alpha: 0.88),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: const Color(0xFF9AF3FF),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _LoginBackgroundPainter oldDelegate) {
    return oldDelegate.mode != mode || oldDelegate.progress != progress;
  }
}
