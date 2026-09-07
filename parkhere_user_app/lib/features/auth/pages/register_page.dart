import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

enum RegisterAccountType { customer, partner }

enum PartnerServiceType {
  parking,
  carWash,
  hotel,
  restaurant,
  tourGuide,
  tourismCompany,
  transport,
  other,
}

class RegisterPage extends ConsumerStatefulWidget {
  final RegisterAccountType initialType;

  const RegisterPage({
    super.key,
    this.initialType = RegisterAccountType.customer,
  });

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final emailCodeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final companyNameController = TextEditingController();
  final cnpjController = TextEditingController();
  final registrationStatusController = TextEditingController();
  final responsibleNameController = TextEditingController();
  final phoneController = TextEditingController();
  final insuranceCompanyController = TextEditingController();
  final instagramController = TextEditingController();
  final websiteController = TextEditingController();
  final socialLinksController = TextEditingController();

  late RegisterAccountType accountType;
  PartnerServiceType serviceType = PartnerServiceType.parking;
  bool hasInsurance = false;
  bool emailVerified = false;
  String? emailToken;
  bool isLoading = false;

  bool get needsInsuranceInfo =>
      accountType == RegisterAccountType.partner &&
      (serviceType == PartnerServiceType.parking ||
          serviceType == PartnerServiceType.carWash);

  String get serviceTypeApiValue {
    switch (serviceType) {
      case PartnerServiceType.parking:
        return 'parking';
      case PartnerServiceType.carWash:
        return 'car_wash';
      case PartnerServiceType.hotel:
        return 'hotel';
      case PartnerServiceType.restaurant:
        return 'restaurant';
      case PartnerServiceType.tourGuide:
        return 'tour_guide';
      case PartnerServiceType.tourismCompany:
        return 'tourism_company';
      case PartnerServiceType.transport:
        return 'transport';
      case PartnerServiceType.other:
        return 'other';
    }
  }

  @override
  void initState() {
    super.initState();
    accountType = widget.initialType;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    emailCodeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    companyNameController.dispose();
    cnpjController.dispose();
    registrationStatusController.dispose();
    responsibleNameController.dispose();
    phoneController.dispose();
    insuranceCompanyController.dispose();
    instagramController.dispose();
    websiteController.dispose();
    socialLinksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPartner = accountType == RegisterAccountType.partner;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              margin: const EdgeInsets.all(20),
              elevation: 14,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isPartner ? "Cadastrar Parceiro" : "Criar Conta Cliente",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF102657),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SegmentedButton<RegisterAccountType>(
                      segments: const [
                        ButtonSegment(
                          value: RegisterAccountType.customer,
                          label: Text("Cliente"),
                          icon: Icon(Icons.person),
                        ),
                        ButtonSegment(
                          value: RegisterAccountType.partner,
                          label: Text("Parceiro"),
                          icon: Icon(Icons.storefront),
                        ),
                      ],
                      selected: {accountType},
                      onSelectionChanged: (value) {
                        setState(() => accountType = value.first);
                      },
                    ),
                    const SizedBox(height: 22),
                    _emailValidationStep(),
                    if (emailVerified) ...[
                      const SizedBox(height: 22),
                      if (isPartner) _partnerFields() else _customerFields(),
                      const SizedBox(height: 22),
                      _passwordFields(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF102657),
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isLoading ? null : _submit,
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  isPartner
                                      ? "Enviar cadastro para análise"
                                      : "Criar conta",
                                  style: const TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Já possui conta? Entrar"),
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

  Widget _customerFields() {
    return Column(children: [_field(nameController, "Nome completo")]);
  }

  Widget _partnerFields() {
    return Column(
      children: [
        DropdownButtonFormField<PartnerServiceType>(
          initialValue: serviceType,
          decoration: const InputDecoration(
            labelText: "Tipo de serviço",
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: PartnerServiceType.parking,
              child: Text("Estacionamento"),
            ),
            DropdownMenuItem(
              value: PartnerServiceType.carWash,
              child: Text("Lava-jato"),
            ),
            DropdownMenuItem(
              value: PartnerServiceType.hotel,
              child: Text("Hotel"),
            ),
            DropdownMenuItem(
              value: PartnerServiceType.restaurant,
              child: Text("Restaurante"),
            ),
            DropdownMenuItem(
              value: PartnerServiceType.tourGuide,
              child: Text("Guia turístico / Tourist guide"),
            ),
            DropdownMenuItem(
              value: PartnerServiceType.tourismCompany,
              child: Text("Empresa de turismo / Tourism company"),
            ),
            DropdownMenuItem(
              value: PartnerServiceType.transport,
              child: Text("Transporte"),
            ),
            DropdownMenuItem(
              value: PartnerServiceType.other,
              child: Text("Outro serviço / Other service"),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => serviceType = value);
          },
        ),
        const SizedBox(height: 12),
        _field(companyNameController, "Nome da empresa"),
        _field(cnpjController, "CNPJ", keyboardType: TextInputType.number),
        _field(registrationStatusController, "Situação cadastral"),
        _field(responsibleNameController, "Responsável legal"),
        _field(
          phoneController,
          "Telefone de contato / Contact phone",
          keyboardType: TextInputType.phone,
        ),
        if (needsInsuranceInfo) ...[
          SwitchListTile(
            value: hasInsurance,
            onChanged: (value) => setState(() => hasInsurance = value),
            title: const Text("Estabelecimento possui seguro?"),
            contentPadding: EdgeInsets.zero,
          ),
          if (hasInsurance)
            _field(insuranceCompanyController, "Qual seguradora/apólice?"),
        ],
        _field(instagramController, "Instagram"),
        _field(websiteController, "Site"),
        _field(socialLinksController, "Outras redes sociais", maxLines: 3),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAFBFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            "Integração Instagram: nesta fase guardamos o perfil/link. A visualização de publicações dentro do app entra no bloco de integração oficial.",
            style: TextStyle(color: Color(0xFF102657)),
          ),
        ),
      ],
    );
  }

  Widget _passwordFields() {
    return Column(
      children: [
        _field(passwordController, "Senha", obscureText: true),
        _field(confirmPasswordController, "Confirmar senha", obscureText: true),
      ],
    );
  }

  Widget _emailValidationStep() {
    return Column(
      children: [
        TextField(
          controller: emailController,
          enabled: !emailVerified,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: accountType == RegisterAccountType.partner
                ? "E-mail de acesso"
                : "E-mail",
            prefixIcon: const Icon(Icons.mail_outline),
            suffixIcon: emailVerified
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
          ),
        ),
        if (!emailVerified) ...[
          const SizedBox(height: 12),
          if (emailToken != null)
            TextField(
              controller: emailCodeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Código recebido (teste: 000000)",
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isLoading
                  ? null
                  : emailToken == null
                  ? _requestEmailCode
                  : _verifyEmailCode,
              icon: Icon(
                emailToken == null ? Icons.mark_email_read : Icons.verified,
              ),
              label: Text(
                emailToken == null ? "Validar e-mail" : "Confirmar codigo",
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscureText = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: obscureText ? 1 : maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => isLoading = true);

    try {
      _validate();

      if (accountType == RegisterAccountType.partner) {
        await ref
            .read(authProvider.notifier)
            .registerPartner(
              serviceType: serviceTypeApiValue,
              companyName: companyNameController.text,
              cnpj: cnpjController.text,
              registrationStatus: registrationStatusController.text,
              responsibleName: responsibleNameController.text,
              email: emailController.text,
              password: passwordController.text,
              phone: phoneController.text,
              hasInsurance: hasInsurance,
              insuranceProvider: insuranceCompanyController.text,
              instagram: instagramController.text,
              website: websiteController.text,
              socialLinks: socialLinksController.text,
            );
      } else {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accountType == RegisterAccountType.partner
                ? "Cadastro enviado para análise documental e vistoria."
                : "Conta criada com sucesso!",
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _requestEmailCode() async {
    if (emailController.text.trim().isEmpty) {
      _showMessage("Informe o e-mail antes de continuar");
      return;
    }

    setState(() => isLoading = true);
    try {
      final token = await ref
          .read(authProvider.notifier)
          .requestEmailValidationCode(emailController.text);
      if (!mounted) return;
      setState(() => emailToken = token);
      _showMessage("Codigo enviado para validacao do e-mail");
    } catch (_) {
      _showMessage("Nao foi possivel validar o e-mail");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _verifyEmailCode() async {
    final token = emailToken;
    if (token == null || emailCodeController.text.trim().isEmpty) {
      _showMessage("Informe o codigo recebido");
      return;
    }

    setState(() => isLoading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .verifyEmailValidationCode(token, emailCodeController.text.trim());
      if (!mounted) return;
      setState(() => emailVerified = true);
      _showMessage("E-mail validado. Continue o cadastro.");
    } catch (_) {
      _showMessage("Codigo invalido ou expirado");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _validate() {
    final isPartner = accountType == RegisterAccountType.partner;
    final requiredControllers = isPartner
        ? [
            companyNameController,
            cnpjController,
            registrationStatusController,
            responsibleNameController,
            phoneController,
            emailController,
            passwordController,
            confirmPasswordController,
          ]
        : [
            nameController,
            emailController,
            passwordController,
            confirmPasswordController,
          ];

    if (requiredControllers.any(
      (controller) => controller.text.trim().isEmpty,
    )) {
      throw Exception("Preencha todos os campos obrigatórios");
    }

    if (!emailVerified) {
      throw Exception("Valide o e-mail antes de concluir o cadastro");
    }

    if (needsInsuranceInfo &&
        hasInsurance &&
        insuranceCompanyController.text.trim().isEmpty) {
      throw Exception("Informe qual seguro o estabelecimento possui");
    }

    if (passwordController.text != confirmPasswordController.text) {
      throw Exception("As senhas não coincidem");
    }

    if (!_isStrongPassword(passwordController.text)) {
      throw Exception(
        "Senha deve ter no mínimo 8 caracteres, letra maiúscula, letra minúscula e caractere especial. Ex: Rig@ud2026",
      );
    }
  }

  bool _isStrongPassword(String password) {
    final hasMinLength = password.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
    return hasMinLength && hasUpper && hasLower && hasSpecial;
  }
}
