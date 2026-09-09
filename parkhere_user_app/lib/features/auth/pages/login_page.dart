import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_state.dart';
import '../providers/auth_provider.dart';
import '../../../core/i18n/app_language.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

enum LoginLanguage { ptBr, en }

enum LoginMode { customer, partner }

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final mfaController = TextEditingController();

  bool isLoading = false;
  bool showPassword = false;
  LoginLanguage language = LoginLanguage.ptBr;
  LoginMode loginMode = LoginMode.customer;
  String? loginError;

  bool get isPortuguese => language == LoginLanguage.ptBr;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    mfaController.dispose();
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
                    Color(0xFF071A3F),
                    Color(0xFF0B2A5B),
                    Color(0xFF37CDE1),
                  ]
                : const [
                    Color(0xFF06142F),
                    Color(0xFF123F75),
                    Color(0xFF65D9E6),
                  ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                child: CustomPaint(
                  key: ValueKey(loginMode),
                  painter: _LoginBackgroundPainter(loginMode),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: _LanguageFlagButton(
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
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
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
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _ParkingLogoMark(),
                          const SizedBox(height: 8),
                          const Text(
                            "ParkHere",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF102657),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPortuguese
                                ? "Mobilidade, vagas e serviços em um só lugar"
                                : "Parking, mobility and services in one place",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF55708F),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _AccessModeSelector(
                            loginMode: displayedLoginMode,
                            isPortuguese: isPortuguese,
                            enabled: !isMfaStep,
                            onChanged: (mode) {
                              ref.read(authProvider.notifier).resetLoginFlow();
                              setState(() {
                                loginMode = mode;
                                loginError = null;
                                mfaController.clear();
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          if (authState.status != AuthStatus.mfaRequired) ...[
                            _textField(
                              controller: emailController,
                              label: isPortuguese ? "E-mail" : "Email",
                              icon: Icons.mail_outline,
                            ),
                            const SizedBox(height: 10),
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
                          ],
                          if (authState.status == AuthStatus.mfaRequired) ...[
                            Text(
                              isPortuguese
                                  ? "Digite o código MFA"
                                  : "Enter MFA code",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF102657),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _textField(
                              controller: mfaController,
                              label: isPortuguese
                                  ? "Código de verificação"
                                  : "Verification code",
                              icon: Icons.verified_user_outlined,
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.all(14),
                                backgroundColor: const Color(0xFF102657),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: isLoading ? null : _submitLogin,
                              child: isLoading
                                  ? const _LoginLoadingLabel()
                                  : Text(
                                      authState.status == AuthStatus.mfaRequired
                                          ? (isPortuguese
                                                ? "Verificar código"
                                                : "Verify code")
                                          : _loginButtonLabel(isPortuguese),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed:
                                authState.status == AuthStatus.mfaRequired
                                ? null
                                : () {
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
                                    initialType: loginMode == LoginMode.customer
                                        ? RegisterAccountType.customer
                                        : RegisterAccountType.partner,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              loginMode == LoginMode.customer
                                  ? (isPortuguese
                                        ? "Criar conta cliente"
                                        : "Create customer account")
                                  : (isPortuguese
                                        ? "Cadastrar estabelecimento parceiro"
                                        : "Register partner business"),
                              style: const TextStyle(
                                color: Color(0xFF169FC4),
                                fontWeight: FontWeight.w700,
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
          color: Colors.white.withValues(alpha: 0.86),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  "assets/branding/logo_rigaud_tech_clean.png",
                  width: 72,
                  height: 20,
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

class _ParkingLogoMark extends StatelessWidget {
  const _ParkingLogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF2AD2E5), Color(0xFF2788E8)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: const [
          Icon(Icons.local_parking, size: 40, color: Colors.white),
          Positioned(
            right: 12,
            bottom: 13,
            child: Icon(Icons.location_on, size: 18, color: Color(0xFF102657)),
          ),
        ],
      ),
    );
  }
}

class _LoginBackgroundPainter extends CustomPainter {
  final LoginMode mode;

  const _LoginBackgroundPainter(this.mode);

  @override
  void paint(Canvas canvas, Size size) {
    final routePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final accentPaint = Paint()
      ..color = const Color(0xFF6FE7F1).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

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

    _drawPin(canvas, Offset(size.width * 0.14, size.height * 0.20), 20);
    _drawPin(canvas, Offset(size.width * 0.82, size.height * 0.30), 16);
    _drawVehicle(
      canvas,
      Offset(size.width * 0.16, size.height * 0.72),
      mode == LoginMode.customer ? Icons.directions_car : Icons.local_car_wash,
      36,
    );
    _drawVehicle(
      canvas,
      Offset(size.width * 0.76, size.height * 0.76),
      mode == LoginMode.customer ? Icons.two_wheeler : Icons.storefront,
      34,
    );
    _drawVehicle(
      canvas,
      Offset(size.width * 0.90, size.height * 0.55),
      Icons.pedal_bike,
      28,
    );

    for (var i = 0; i < 16; i++) {
      final x = (math.sin(i * 2.1) * 0.5 + 0.5) * size.width;
      final y = (i / 16) * size.height;
      canvas.drawCircle(
        Offset(x, y),
        2.2,
        Paint()..color = Colors.white.withValues(alpha: 0.13),
      );
    }
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

  void _drawVehicle(Canvas canvas, Offset center, IconData icon, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white.withValues(alpha: 0.18),
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
    return oldDelegate.mode != mode;
  }
}
