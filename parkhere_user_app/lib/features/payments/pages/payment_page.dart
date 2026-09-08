import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';

import '../../account/pages/wallet_page.dart';
import '../../account/models/account_models.dart';
import '../../account/providers/account_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../model/payment_method_enum.dart';
import '../services/payment_service.dart';

class PaymentPage extends ConsumerStatefulWidget {
  final double amount;
  final String? reservationId;
  final bool payNow;
  final FutureOr<void> Function() onPaymentSuccess;

  const PaymentPage({
    super.key,
    required this.amount,
    this.reservationId,
    required this.payNow,
    required this.onPaymentSuccess,
  });

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  PaymentMethod? _selectedMethod;
  final cvvController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _quote;

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    final reservationId = widget.reservationId;
    final token = ref.read(authProvider).accessToken;
    if (reservationId == null || token == null) return;
    try {
      final quote = await PaymentService().reservationQuote(
        reservationId,
        token,
      );
      if (mounted) setState(() => _quote = quote);
    } catch (_) {
      // The payment page can still use the reservation total if the quote is unavailable.
    }
  }

  @override
  void dispose() {
    cvvController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    final account = ref.read(accountProvider);
    final activeMethod = account.activePaymentMethod;

    final paymentMethod = activeMethod == null
        ? null
        : _selectedMethod ?? _mapMethod(activeMethod.type);

    if (activeMethod == null || paymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecione um método de pagamento")),
      );
      return;
    }

    if (_requiresCvv(activeMethod) && cvvController.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Informe o CVV para continuar")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final accessToken = ref.read(authProvider).accessToken;
      if (accessToken == null) {
        throw Exception("Sessao expirada. Entre novamente.");
      }

      final result = await PaymentService().processPayment(
        amount: widget.amount,
        method: paymentMethod,
        accessToken: accessToken,
        reservationId: widget.reservationId,
      );

      if (result.success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isSimulated
                  ? 'Pagamento simulado. Nenhuma cobrança foi realizada.'
                  : 'Pagamento confirmado.',
            ),
          ),
        );
        await widget.onPaymentSuccess();

        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        throw Exception("Pagamento recusado");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro: ${e.toString()}")));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    final activeMethod = account.activePaymentMethod;

    return Scaffold(
      appBar: AppBar(title: const Text("Pagamento")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (!account.hasActivePaymentMethod)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Cadastre uma forma de pagamento para continuar.",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WalletPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.account_balance_wallet),
                        label: const Text("Abrir carteira"),
                      ),
                    ],
                  ),
                ),
              if (activeMethod != null) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet),
                    title: Text(activeMethod.label),
                    subtitle: Text(_activeMethodDescription(activeMethod)),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const WalletPage()),
                        );
                      },
                      child: const Text("Trocar"),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_requiresCvv(activeMethod))
                  TextField(
                    controller: cvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      labelText: "CVV",
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                const SizedBox(height: 18),
              ],

              if ((_selectedMethod ??
                      (activeMethod == null
                          ? null
                          : _mapMethod(activeMethod.type))) ==
                  PaymentMethod.pix)
                Card(
                  color: const Color(0xFFEAFBFF),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text('QR Code Pix / Pix QR Code'),
                        QrImageView(
                          data:
                              'parkhere://pix/${widget.reservationId ?? widget.amount}',
                          size: 150,
                        ),
                        const Text('Validade: 15:00 / Valid for 15:00'),
                        TextButton.icon(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(
                              text:
                                  'parkhere://pix/${widget.reservationId ?? widget.amount}',
                            ),
                          ),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copiar código / Copy code'),
                        ),
                      ],
                    ),
                  ),
                ),

              Text(
                widget.payNow
                    ? "Pagamento necessário para iniciar"
                    : "Pagamento no checkout",
                style: const TextStyle(fontSize: 18),
              ),

              const SizedBox(height: 20),

              Text(
                "Valor: R\$ ${widget.amount.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_quote != null)
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Resumo da reserva'),
                        trailing: Text(
                          'R\$ ${(_quote!['reservation_amount'] as num).toDouble().toStringAsFixed(2)}',
                        ),
                      ),
                      ListTile(
                        title: const Text('Taxa do usuário'),
                        trailing: Text(
                          'R\$ ${(_quote!['customer_fee_amount'] as num).toDouble().toStringAsFixed(2)}',
                        ),
                      ),
                      ListTile(
                        title: const Text('Taxa do estabelecimento'),
                        trailing: Text(
                          'R\$ ${(_quote!['establishment_fee_amount'] as num).toDouble().toStringAsFixed(2)}',
                        ),
                      ),
                      ListTile(
                        title: const Text('Total'),
                        trailing: Text(
                          'R\$ ${(_quote!['total_amount'] as num).toDouble().toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.reservationId != null) ...[
                const SizedBox(height: 8),
                const Text(
                  "Pagamento via Mercado Pago preparado com split ParkHere/parceiro.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF55708F)),
                ),
              ],

              const SizedBox(height: 30),

              if (activeMethod != null)
                SegmentedButton<PaymentMethod>(
                  segments: [
                    if (activeMethod.type == WalletMethodType.pix)
                      const ButtonSegment(
                        value: PaymentMethod.pix,
                        label: Text("Pix"),
                        icon: Icon(Icons.qr_code_2),
                      ),
                    if (activeMethod.type == WalletMethodType.creditCard)
                      const ButtonSegment(
                        value: PaymentMethod.creditCard,
                        label: Text("Credito"),
                        icon: Icon(Icons.credit_card),
                      ),
                    if (activeMethod.type == WalletMethodType.debitCard)
                      const ButtonSegment(
                        value: PaymentMethod.debitCard,
                        label: Text("Debito"),
                        icon: Icon(Icons.payment),
                      ),
                  ],
                  selected: {_selectedMethod ?? _mapMethod(activeMethod.type)},
                  onSelectionChanged: (value) {
                    setState(() => _selectedMethod = value.first);
                  },
                ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading || !account.hasActivePaymentMethod
                      ? null
                      : _processPayment,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Confirmar Pagamento"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _requiresCvv(WalletMethodModel method) {
    return method.type == WalletMethodType.creditCard ||
        method.type == WalletMethodType.debitCard;
  }

  PaymentMethod _mapMethod(WalletMethodType type) {
    switch (type) {
      case WalletMethodType.creditCard:
        return PaymentMethod.creditCard;
      case WalletMethodType.debitCard:
        return PaymentMethod.debitCard;
      case WalletMethodType.pix:
        return PaymentMethod.pix;
    }
  }

  String _activeMethodDescription(WalletMethodModel method) {
    switch (method.type) {
      case WalletMethodType.creditCard:
        return "Cartao de credito | CVV solicitado agora";
      case WalletMethodType.debitCard:
        return "Cartao de debito | CVV solicitado agora";
      case WalletMethodType.pix:
        return method.pixKey ?? "Pix cadastrado";
    }
  }
}
