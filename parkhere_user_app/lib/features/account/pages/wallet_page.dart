import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/account_models.dart';
import '../providers/account_provider.dart';

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
    final isPix = type == WalletMethodType.pix;

    return Scaffold(
      appBar: AppBar(title: const Text('Carteira')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Formas de pagamento',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Salve seus cartões ou Pix. O CVV nunca fica armazenado e sera solicitado no pagamento.',
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
              ButtonSegment(
                value: WalletMethodType.pix,
                label: Text('Pix'),
                icon: Icon(Icons.qr_code_2),
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
    final isPix = type == WalletMethodType.pix;

    if (isPix && pixController.text.trim().isEmpty) {
      _showError('Informe a chave Pix.');
      return;
    }

    if (!isPix &&
        (holderController.text.trim().isEmpty ||
            numberController.text.trim().length < 4 ||
            expiryController.text.trim().isEmpty)) {
      _showError('Informe nome, numero e validade do cartao.');
      return;
    }

    final cardDigits = numberController.text.replaceAll(RegExp(r'\D'), '');
    final lastFour = cardDigits.length >= 4
        ? cardDigits.substring(cardDigits.length - 4)
        : null;
    final brand = isPix ? null : _detectBrand(cardDigits);
    final label = isPix
        ? 'Pix ${pixController.text.trim()}'
        : '$brand final $lastFour';

    await ref
        .read(accountProvider.notifier)
        .addWalletMethod(
          WalletMethodModel(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            type: type,
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

  String _detectBrand(String digits) {
    if (digits.startsWith('4')) return 'Visa';
    if (digits.startsWith('5')) return 'Mastercard';
    if (digits.startsWith('3')) return 'Amex';
    if (digits.startsWith('6')) return 'Elo';
    return 'Cartao';
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.softCyan,
              foregroundColor: AppTheme.primary,
              child: Icon(isPix ? Icons.qr_code_2 : Icons.credit_card),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.label,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isPix
                        ? method.pixKey ?? 'Pix cadastrado'
                        : '${method.holderName ?? 'Titular'} | Val. ${method.expiry ?? '--/--'}',
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle, color: AppTheme.success)
            else
              TextButton(onPressed: onActivate, child: const Text('Usar')),
          ],
        ),
      ),
    );
  }
}
