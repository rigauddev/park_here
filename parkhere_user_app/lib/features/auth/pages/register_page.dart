import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/widgets/api_feedback.dart';
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
  final cpfController = TextEditingController();
  final emailController = TextEditingController();
  final emailCodeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final companyNameController = TextEditingController();
  final documentController = TextEditingController();
  final responsibleNameController = TextEditingController();
  final phoneController = TextEditingController();
  final insuranceCompanyController = TextEditingController();
  final websiteController = TextEditingController();

  late RegisterAccountType accountType;
  PartnerServiceType serviceType = PartnerServiceType.parking;
  String documentType = 'cnpj';
  bool hasInsurance = false;
  bool emailVerified = false;
  String? emailToken;
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmation = true;
  Uint8List? profilePhoto;
  final Map<String, PlatformFile> partnerDocuments = {};
  String personalDocumentType = 'rg';

  bool get needsInsuranceInfo => accountType == RegisterAccountType.partner;

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
    cpfController.dispose();
    emailController.dispose();
    emailCodeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    companyNameController.dispose();
    documentController.dispose();
    responsibleNameController.dispose();
    phoneController.dispose();
    insuranceCompanyController.dispose();
    websiteController.dispose();
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
                    Chip(
                      avatar: Icon(
                        isPartner ? Icons.storefront : Icons.person,
                        size: 18,
                      ),
                      label: Text(
                        isPartner
                            ? 'Cadastro de parceiro'
                            : 'Cadastro de cliente',
                      ),
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
    return Column(
      children: [
        _field(nameController, "Nome completo"),
        _field(cpfController, "CPF", keyboardType: TextInputType.number),
        _field(phoneController, "Telefone", keyboardType: TextInputType.phone),
        OutlinedButton.icon(
          onPressed: isLoading ? null : _pickProfilePhoto,
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(
            profilePhoto == null
                ? 'Adicionar foto de perfil (opcional)'
                : 'Foto selecionada',
          ),
        ),
      ],
    );
  }

  Future<void> _pickProfilePhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => profilePhoto = bytes);
    }
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
        DropdownButtonFormField<String>(
          initialValue: documentType,
          decoration: const InputDecoration(
            labelText: "Documento do parceiro / Partner document",
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'cnpj', child: Text('CNPJ')),
            DropdownMenuItem(value: 'cpf', child: Text('CPF')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => documentType = value);
          },
        ),
        const SizedBox(height: 12),
        _field(
          documentController,
          documentType == 'cnpj' ? "CNPJ" : "CPF",
          keyboardType: TextInputType.number,
        ),
        _field(responsibleNameController, "Responsável legal"),
        _field(
          phoneController,
          "Telefone de contato / Contact phone",
          keyboardType: TextInputType.phone,
        ),
        SwitchListTile(
          value: hasInsurance,
          onChanged: (value) => setState(() => hasInsurance = value),
          title: const Text("Estabelecimento possui seguro?"),
          contentPadding: EdgeInsets.zero,
        ),
        if (hasInsurance)
          _field(insuranceCompanyController, "Qual seguradora/apólice?"),
        _field(websiteController, "Site"),
        const SizedBox(height: 8),
        _partnerDocumentPicker(
          'alvara',
          documentType == 'cnpj'
              ? 'Alvará (obrigatório para CNPJ)'
              : 'Alvará (opcional)',
        ),
        DropdownButtonFormField<String>(
          initialValue: personalDocumentType,
          decoration: const InputDecoration(
            labelText: 'Documento do responsável',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'rg', child: Text('RG')),
            DropdownMenuItem(value: 'cnh', child: Text('CNH')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => personalDocumentType = value);
          },
        ),
        const SizedBox(height: 10),
        _partnerDocumentPicker('personal', 'RG ou CNH (obrigatório)'),
        if (hasInsurance)
          _partnerDocumentPicker(
            'insurance_policy',
            'Documento do seguro (obrigatório)',
          ),
      ],
    );
  }

  Widget _partnerDocumentPicker(String key, String label) {
    final selected = partnerDocuments[key];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : () => _pickPartnerDocument(key),
        icon: Icon(selected == null ? Icons.attach_file : Icons.check_circle),
        label: Text(
          selected == null
              ? 'Anexar $label (PDF/JPG/PNG)'
              : '${selected.name} anexado',
        ),
      ),
    );
  }

  Future<void> _pickPartnerDocument(String key) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.single.bytes == null || !mounted) return;
    setState(() => partnerDocuments[key] = result.files.single);
  }

  Widget _passwordFields() {
    return Column(
      children: [
        _field(
          passwordController,
          "Senha (mín. 8, maiúscula, minúscula e símbolo)",
          obscureText: obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              obscurePassword ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () => setState(() => obscurePassword = !obscurePassword),
          ),
        ),
        _field(
          confirmPasswordController,
          "Confirmar senha",
          obscureText: obscureConfirmation,
          suffixIcon: IconButton(
            icon: Icon(
              obscureConfirmation ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () =>
                setState(() => obscureConfirmation = !obscureConfirmation),
          ),
        ),
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
    Widget? suffixIcon,
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
          suffixIcon: suffixIcon,
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
              documentType: documentType,
              documentNumber: documentController.text,
              responsibleName: responsibleNameController.text,
              email: emailController.text,
              password: passwordController.text,
              phone: phoneController.text,
              hasInsurance: hasInsurance,
              insuranceProvider: insuranceCompanyController.text,
              website: websiteController.text,
              documents: _partnerDocumentPayload(),
            );
      } else {
        await ref
            .read(authProvider.notifier)
            .registerCustomer(
              name: nameController.text,
              cpf: cpfController.text,
              email: emailController.text,
              password: passwordController.text,
              phone: phoneController.text,
            );
        if (profilePhoto != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'profile_avatar_${emailController.text.trim().toLowerCase()}',
            base64Encode(profilePhoto!),
          );
        }
      }

      if (!mounted) return;

      await ApiFeedback.show(
        context,
        accountType == RegisterAccountType.partner
            ? 'Cadastro enviado para análise documental e vistoria.'
            : 'Conta criada com sucesso!',
        isError: false,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      await ApiFeedback.show(context, e.toString());
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
            documentController,
            responsibleNameController,
            phoneController,
            emailController,
            passwordController,
            confirmPasswordController,
          ]
        : [
            nameController,
            cpfController,
            phoneController,
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

    if (isPartner) {
      if (documentType == 'cnpj' && partnerDocuments['alvara'] == null) {
        throw Exception('Anexe o alvará do estabelecimento.');
      }
      if (partnerDocuments['personal'] == null) {
        throw Exception('Anexe RG ou CNH do responsável.');
      }
      if (hasInsurance && partnerDocuments['insurance_policy'] == null) {
        throw Exception('Anexe o documento do seguro informado.');
      }
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

  List<Map<String, dynamic>> _partnerDocumentPayload() {
    final payload = <Map<String, dynamic>>[];
    for (final entry in partnerDocuments.entries) {
      final file = entry.value;
      final bytes = file.bytes;
      if (bytes == null) continue;
      final type = entry.key == 'personal' ? personalDocumentType : entry.key;
      payload.add({
        'document_type': type,
        'file_name': file.name,
        'content_base64': base64Encode(bytes),
      });
    }
    return payload;
  }

  bool _isStrongPassword(String password) {
    final hasMinLength = password.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
    return hasMinLength && hasUpper && hasLower && hasSpecial;
  }
}
