import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/account_models.dart';
import '../providers/account_provider.dart';
import '../../auth/providers/auth_provider.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  final holderController = TextEditingController();
  final numberController = TextEditingController();
  final expiryController = TextEditingController();
  final pixController = TextEditingController();
  WalletMethodType type = WalletMethodType.creditCard;
  String selectedBrand = 'Visa';

  @override
  void dispose() {
    holderController.dispose();
    numberController.dispose();
    expiryController.dispose();
    pixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    final isPartner = ref.watch(authProvider).isPartnerSession;
    final isPix = isPartner || type == WalletMethodType.pix;

    return Scaffold(
      appBar: AppBar(title: Text(isPartner ? 'Conta de repasse' : 'Carteira')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            isPartner ? 'Recebimento das reservas' : 'Cartões para pagamento',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            isPartner
                ? 'Cadastre a chave Pix que receberá os repasses das reservas.'
                : 'Cadastre cartões. O Pix é gerado pelo Mercado Pago no momento do pagamento.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 18),
          if (account.walletMethods.isEmpty)
            const _EmptyWallet()
          else
            for (final method in account.walletMethods)
              _PaymentMethodCard(
                method: method,
                isActive: account.activePaymentMethod?.id == method.id,
                onActivate: () {
                  ref
                      .read(accountProvider.notifier)
                      .setActiveWalletMethod(method.id);
                },
              ),
          const SizedBox(height: 24),
          Text(
            'Adicionar metodo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (!isPartner)
            SegmentedButton<WalletMethodType>(
              segments: const [
                ButtonSegment(
                  value: WalletMethodType.creditCard,
                  label: Text('Credito'),
                  icon: Icon(Icons.credit_card),
                ),
                ButtonSegment(
                  value: WalletMethodType.debitCard,
                  label: Text('Debito'),
                  icon: Icon(Icons.payment),
                ),
              ],
              selected: {type},
              onSelectionChanged: (value) => setState(() => type = value.first),
            ),
          const SizedBox(height: 14),
          if (isPix)
            TextField(
              controller: pixController,
              decoration: const InputDecoration(
                labelText: 'Chave Pix',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: selectedBrand,
              decoration: const InputDecoration(
                labelText: 'Bandeira do cartão',
                prefixIcon: Icon(Icons.credit_card),
              ),
              items:
                  const [
                        'Visa',
                        'Mastercard',
                        'Elo',
                        'American Express',
                        'Hipercard',
                      ]
                      .map(
                        (brand) =>
                            DropdownMenuItem(value: brand, child: Text(brand)),
                      )
                      .toList(),
              onChanged: (value) =>
                  setState(() => selectedBrand = value ?? 'Visa'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: holderController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Nome impresso no cartao',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: numberController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(19),
                _CardNumberFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Numero do cartao',
                prefixIcon: Icon(Icons.credit_card),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: expiryController,
              keyboardType: TextInputType.datetime,
              inputFormatters: [_ExpiryFormatter()],
              decoration: const InputDecoration(
                labelText: 'Validade MM/AA',
                prefixIcon: Icon(Icons.event_outlined),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _addMethod,
            icon: const Icon(Icons.add_card),
            label: const Text('Salvar metodo'),
          ),
        ],
      ),
    );
  }

  Future<void> _addMethod() async {
    final isPix =
        ref.read(authProvider).isPartnerSession || type == WalletMethodType.pix;

    if (isPix && pixController.text.trim().isEmpty) {
      _showError('Informe a chave Pix.');
      return;
    }

    if (!isPix &&
        (holderController.text.trim().isEmpty ||
            numberController.text.replaceAll(RegExp(r'\D'), '').length < 12 ||
            !_isValidExpiry(expiryController.text.trim()))) {
      _showError('Informe nome, numero e validade do cartao.');
      return;
    }

    final cardDigits = numberController.text.replaceAll(RegExp(r'\D'), '');
    final lastFour = cardDigits.length >= 4
        ? cardDigits.substring(cardDigits.length - 4)
        : null;
    final brand = isPix ? null : selectedBrand;
    final label = isPix
        ? 'Pix ${pixController.text.trim()}'
        : '$brand final $lastFour';

    await ref
        .read(accountProvider.notifier)
        .addWalletMethod(
          WalletMethodModel(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            type: isPix ? WalletMethodType.pix : type,
            label: label,
            holderName: isPix ? null : holderController.text.trim(),
            brand: brand,
            lastFour: lastFour,
            expiry: isPix ? null : expiryController.text.trim(),
            pixKey: isPix ? pixController.text.trim() : null,
            isActive: true,
          ),
        );

    holderController.clear();
    numberController.clear();
    expiryController.clear();
    pixController.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Metodo salvo como principal.')),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isValidExpiry(String value) {
    final match = RegExp(r'^(0[1-9]|1[0-2])/(\d{2})$').firstMatch(value);
    if (match == null) return false;
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    final now = DateTime.now();
    return DateTime(year, month + 1).isAfter(DateTime(now.year, now.month));
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(oldValue, newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final groups = <String>[];
    for (var i = 0; i < digits.length; i += 4) {
      groups.add(digits.substring(i, (i + 4).clamp(0, digits.length)));
    }
    final text = groups.join(' ');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(oldValue, newValue) {
    final digits = newValue.text
        .replaceAll(RegExp(r'\D'), '')
        .substring(
          0,
          newValue.text.replaceAll(RegExp(r'\D'), '').length.clamp(0, 4),
        );
    final text = digits.length > 2
        ? '${digits.substring(0, 2)}/${digits.substring(2)}'
        : digits;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _EmptyWallet extends StatelessWidget {
  const _EmptyWallet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softCyan,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('Nenhuma forma de pagamento cadastrada.'),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final WalletMethodModel method;
  final bool isActive;
  final VoidCallback onActivate;

  const _PaymentMethodCard({
    required this.method,
    required this.isActive,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final isPix = method.type == WalletMethodType.pix;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102657), Color(0xFF087EE1)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card, color: Colors.white70),
              const Spacer(),
              Text(
                method.brand ?? (isPix ? 'PIX' : 'CARTÃO'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, color: Colors.white),
              ],
            ],
          ),
          const SizedBox(height: 22),
          Text(
            isPix
                ? (method.pixKey ?? 'Pix cadastrado')
                : '••••  ••••  ••••  ${method.lastFour ?? '••••'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  (method.holderName ?? 'TITULAR').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                method.expiry ?? '',
                style: const TextStyle(color: Colors.white70),
              ),
              if (!isActive)
                TextButton(
                  onPressed: onActivate,
                  child: const Text(
                    'Usar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
