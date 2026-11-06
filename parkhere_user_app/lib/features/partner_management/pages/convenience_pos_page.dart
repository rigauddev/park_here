import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/local_storage_service.dart';
import 'barcode_scanner_page.dart';

class ConveniencePosPage extends StatefulWidget {
  final String parkingId;
  final String parkingName;

  const ConveniencePosPage({
    super.key,
    required this.parkingId,
    required this.parkingName,
  });

  @override
  State<ConveniencePosPage> createState() => _ConveniencePosPageState();
}

class _ConveniencePosPageState extends State<ConveniencePosPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _search = TextEditingController();
  final _received = TextEditingController();
  final _cpfController = TextEditingController();

  late TabController _tabController;

  List<Map<String, dynamic>> _products = [];
  final Map<String, int> _cart = {};
  final Map<String, double> _discounts = {}; // product_id -> discount_percent

  List<Map<String, dynamic>> _salesHistory = [];
  List<Map<String, dynamic>> _bleedsHistory = [];
  bool _loadingSales = false;
  bool _loadingBleeds = false;
  int _historySubTab = 0; // 0 = Vendas, 1 = Sangrias

  String _paymentMethod = 'cash';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_tabController.indexIsChanging) {
        _loadSalesHistory();
        _loadBleedsHistory();
      }
    });
    _loadProducts();
  }

  @override
  void dispose() {
    _search.dispose();
    _received.dispose();
    _cpfController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = (await LocalStorageService().getTokens())['access'];
    if (token == null) throw Exception('Sessão expirada.');
    return token;
  }

  Future<void> _loadProducts() async {
    try {
      final result = await _api.getAuthorized(
        '/partners/parking-management/${widget.parkingId}/conveniences',
        await _token(),
      );
      if (!mounted) return;
      setState(() {
        _products = result.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _loadSalesHistory() async {
    setState(() => _loadingSales = true);
    try {
      final result = await _api.getAuthorized(
        '/partners/parking-management/${widget.parkingId}/convenience-sales?limit=50',
        await _token(),
      );
      if (!mounted) return;
      setState(() {
        _salesHistory = result.whereType<Map<String, dynamic>>().toList();
        _loadingSales = false;
      });
    } catch (error) {
      if (mounted) setState(() => _loadingSales = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar histórico: $error')));
      }
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _products;
    return _products.where((item) {
      final name = '${item['name']} ${item['barcode'] ?? ''}'.toLowerCase();
      return name.contains(query);
    }).toList();
  }

  double get _total => _cart.entries.fold(0.0, (sum, entry) {
    final product = _products.firstWhere((item) => item['id'] == entry.key);
    final price = (product['price'] as num? ?? 0).toDouble();
    final discount = _discounts[entry.key] ?? 0.0;
    final itemTotal = (price * entry.value) * (1.0 - (discount / 100.0));
    return sum + itemTotal;
  });

  double get _rawTotal => _cart.entries.fold(0.0, (sum, entry) {
    final product = _products.firstWhere((item) => item['id'] == entry.key);
    final price = (product['price'] as num? ?? 0).toDouble();
    return sum + (price * entry.value);
  });

  double get _totalDiscount => _rawTotal - _total;

  Future<void> _setDiscount(String productId) async {
    final currentDiscount = _discounts[productId] ?? 0.0;
    final controller = TextEditingController(
      text: currentDiscount > 0 ? currentDiscount.toStringAsFixed(0) : '',
    );

    final newDiscount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aplicar Desconto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informe a porcentagem de desconto (0 a 100%):'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Desconto (%)',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0.0),
            child: const Text('Remover'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text.replaceAll(',', '.'));
              if (val != null && val >= 0 && val <= 100) {
                Navigator.pop(ctx, val);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Porcentagem inválida (0 a 100).')),
                );
              }
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    if (newDiscount != null && mounted) {
      setState(() {
        if (newDiscount > 0) {
          _discounts[productId] = newDiscount;
        } else {
          _discounts.remove(productId);
        }
      });
    }
  }

  Future<void> _setGlobalDiscount() async {
    final controller = TextEditingController();

    final newDiscount = await showDialog<double>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Desconto Geral na Venda'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informe a porcentagem de desconto a aplicar em todos os itens do carrinho:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Desconto Geral (%)',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('5%'),
                  onPressed: () => controller.text = '5',
                ),
                ActionChip(
                  label: const Text('10%'),
                  onPressed: () => controller.text = '10',
                ),
                ActionChip(
                  label: const Text('15%'),
                  onPressed: () => controller.text = '15',
                ),
                ActionChip(
                  label: const Text('20%'),
                  onPressed: () => controller.text = '20',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(0.0),
            child: const Text('Zerar Descontos'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text.replaceAll(',', '.'));
              if (val != null && val >= 0 && val <= 100) {
                Navigator.of(dialogCtx, rootNavigator: true).pop(val);
              } else {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  const SnackBar(content: Text('Porcentagem inválida (0 a 100).')),
                );
              }
            },
            child: const Text('Aplicar Desconto'),
          ),
        ],
      ),
    );

    if (newDiscount != null && mounted) {
      setState(() {
        if (newDiscount > 0) {
          for (final key in _cart.keys) {
            _discounts[key] = newDiscount;
          }
        } else {
          _discounts.clear();
        }
      });
    }
  }

  Future<void> _printThermalReceipt(Map<String, dynamic> sale) async {
    final saleId = sale['id'] as String? ?? '';
    final shortId = saleId.length > 6 ? saleId.substring(saleId.length - 6) : saleId;
    final total = (sale['total_amount'] as num? ?? 0).toDouble();
    final discount = (sale['discount_total'] as num? ?? 0).toDouble();
    final items = (sale['items'] as List<dynamic>? ?? []);
    final cpf = sale['customer_cpf'] as String?;
    final payment = _paymentLabel(sale['payment_method'] as String? ?? '');
    final createdAt = sale['created_at'] != null ? DateTime.tryParse(sale['created_at'] as String)?.toLocal() : DateTime.now();
    final dateStr = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '';
    final operatorName = sale['operator_name'] as String? ?? 'Operador do Turno';

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  widget.parkingName.toUpperCase(),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'COMPROVANTE NAO FISCAL',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Center(
                child: pw.Text('--------------------------------', style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.Text('VENDA: #$shortId', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('DATA: $dateStr', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('OPERADOR: $operatorName', style: const pw.TextStyle(fontSize: 8)),
              if (cpf != null && cpf.isNotEmpty)
                pw.Text('CPF CLIENTE: $cpf', style: const pw.TextStyle(fontSize: 8)),
              pw.Center(
                child: pw.Text('--------------------------------', style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ITEM', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('TOTAL (R\$)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),
              for (final item in items)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${item['quantity']}x ${item['product_name'] ?? 'Produto'}',
                        style: const pw.TextStyle(fontSize: 8),
                        maxLines: 1,
                      ),
                    ),
                    pw.Text(
                      (item['total_price'] as num? ?? 0).toStringAsFixed(2),
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              pw.Center(
                child: pw.Text('--------------------------------', style: const pw.TextStyle(fontSize: 8)),
              ),
              if (discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('DESCONTO:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('- R\$ ${discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL A PAGAR:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('R\$ ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text('FORMA PAGTO: $payment', style: const pw.TextStyle(fontSize: 8)),
              if (sale['change_amount'] != null && (sale['change_amount'] as num) > 0)
                pw.Text('TROCO: R\$ ${(sale['change_amount'] as num).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
              pw.Center(
                child: pw.Text('--------------------------------', style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.Center(
                child: pw.Text(
                  'OBRIGADO PELA PREFERENCIA!\nVOLTE SEMPRE',
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Comprovante_Venda_$shortId.pdf',
    );
  }

  Future<void> _shareReceiptWhatsApp(Map<String, dynamic> sale) async {
    final saleId = sale['id'] as String? ?? '';
    final shortId = saleId.length > 6 ? saleId.substring(saleId.length - 6) : saleId;
    final total = (sale['total_amount'] as num? ?? 0).toDouble();
    final discount = (sale['discount_total'] as num? ?? 0).toDouble();
    final items = (sale['items'] as List<dynamic>? ?? []);
    final cpf = sale['customer_cpf'] as String?;
    final payment = _paymentLabel(sale['payment_method'] as String? ?? '');
    final createdAt = sale['created_at'] != null ? DateTime.tryParse(sale['created_at'] as String)?.toLocal() : DateTime.now();
    final dateStr = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '';
    final operatorName = sale['operator_name'] as String? ?? 'Operador do Turno';

    final sb = StringBuffer();
    sb.writeln('*${widget.parkingName.toUpperCase()}*');
    sb.writeln('*COMPROVANTE NÃO FISCAL*');
    sb.writeln('--------------------------------');
    sb.writeln('📋 *Venda:* #$shortId');
    sb.writeln('📅 *Data:* $dateStr');
    sb.writeln('👤 *Operador:* $operatorName');
    if (cpf != null && cpf.isNotEmpty) {
      sb.writeln('🪪 *CPF Cliente:* $cpf');
    }
    sb.writeln('--------------------------------');
    sb.writeln('*ITENS:*');
    for (final item in items) {
      final name = item['product_name'] ?? 'Produto';
      final q = item['quantity'];
      final p = (item['total_price'] as num? ?? 0).toStringAsFixed(2);
      sb.writeln(' • ${q}x $name: R\$ $p');
    }
    sb.writeln('--------------------------------');
    if (discount > 0) {
      sb.writeln('Desconto: - R\$ ${discount.toStringAsFixed(2)}');
    }
    sb.writeln('💰 *TOTAL:* R\$ ${total.toStringAsFixed(2)}');
    sb.writeln('💳 *Pagamento:* $payment');
    if (sale['change_amount'] != null && (sale['change_amount'] as num) > 0) {
      sb.writeln('Troco: R\$ ${(sale['change_amount'] as num).toStringAsFixed(2)}');
    }
    sb.writeln('--------------------------------');
    sb.writeln('Agradecemos a sua preferência!');

    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(sb.toString())}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
        );
      }
    }
  }

  Future<void> _showReceiptDialog(Map<String, dynamic> sale) async {
    final saleId = sale['id'] as String? ?? '';
    final shortId = saleId.length > 6 ? saleId.substring(saleId.length - 6) : saleId;
    final total = (sale['total_amount'] as num? ?? 0).toDouble();
    final discount = (sale['discount_total'] as num? ?? 0).toDouble();
    final items = (sale['items'] as List<dynamic>? ?? []);
    final cpf = sale['customer_cpf'] as String?;
    final payment = _paymentLabel(sale['payment_method'] as String? ?? '');
    final changeVal = (sale['change_amount'] as num? ?? 0).toDouble();

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Comprovante #$shortId'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        widget.parkingName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const Center(
                      child: Text('CUPOM NÃO FISCAL', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                    const Divider(height: 16),
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text('${item['quantity']}x ${item['product_name'] ?? 'Item'}'),
                            const Spacer(),
                            Text('R\$ ${(item['total_price'] as num? ?? 0).toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
                    const Divider(height: 16),
                    if (discount > 0)
                      Row(
                        children: [
                          const Text('Desconto:', style: TextStyle(color: Colors.green)),
                          const Spacer(),
                          Text('- R\$ ${discount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green)),
                        ],
                      ),
                    Row(
                      children: [
                        const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        Text('R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Pagamento: $payment', style: const TextStyle(fontSize: 12)),
                    if (changeVal > 0)
                      Text('Troco: R\$ ${changeVal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                    if (cpf != null && cpf.isNotEmpty)
                      Text('CPF no cupom: $cpf', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade800,
                        side: BorderSide(color: Colors.green.shade600),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _shareReceiptWhatsApp(sale),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade900,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _printThermalReceipt(sale),
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Imprimir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  // Gera um número de venda composto apenas por dígitos (6 últimos ou hash).
  String _saleNumber(String saleId) {
    // Extrai apenas dígitos do UUID.
    final digits = saleId.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 6) return digits.substring(digits.length - 6);
    if (digits.isNotEmpty) return digits.padLeft(6, '0');
    // Fallback: hash numérico de 6 dígitos.
    return (saleId.hashCode.abs() % 1000000).toString().padLeft(6, '0');
  }

  // ... existing code ...
  Future<void> _finishSale() async {
    if (_cart.isEmpty) return;
    final received = double.tryParse(_received.text.replaceAll(',', '.'));
    if (_paymentMethod == 'cash' && (received == null || received < _total)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valor recebido insuficiente.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final token = await _token();
      final payload = {
        'items': _cart.entries.map((e) => {
              'product_id': e.key,
              'quantity': e.value,
              'discount_percent': _discounts[e.key] ?? 0,
            }).toList(),
        'cpf': _cpfController.text.trim(),
        'payment_method': _paymentMethod,
        'received_amount': received,
      };
      final result = await _api.postAuthorized('/partners/${widget.parkingId}/conveniences/sale', payload, token);

      // Captura os itens antes de limpar o estado.
      final saleItems = (result['items'] as List<dynamic>? ?? []);
      final enrichedItems = saleItems.map((it) {
        final pid = it['product_id'] as String?;
        final prod = _products.firstWhere((p) => p['id'] == pid, orElse: () => <String, dynamic>{});
        return {
          'product_name': prod['name'] ?? 'Produto',
          'quantity': it['quantity'],
          'total_price': it['total_price'] ?? ((prod['price'] as num? ?? 0) * (it['quantity'] as num? ?? 1)),
        };
      }).toList();
      result['items'] = enrichedItems;

      // Limpa o estado APÓS capturar os dados.
      setState(() {
        _cart.clear();
        _discounts.clear();
        _received.clear();
        _cpfController.clear();
        _saving = false;
      });

      // Aguarda o próximo frame para garantir que a UI está estável antes de abrir dialogs.
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;

      if (_paymentMethod == 'pix') {
        await showDialog<void>(
          context: context,
          useRootNavigator: true,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Pix simulado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Use este QR Code apenas para simulação local.'),
                const SizedBox(height: 12),
                QrImageView(
                  data: 'PARKHERE-MOCK-PIX-${result['id']}-${result['total_amount']}',
                  size: 220,
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
                child: const Text('Prosseguir'),
              ),
            ],
          ),
        );
      }

      if (mounted) {
        await _showReceiptDialog(result);
      }
    } catch (e) {
      if (mounted) await ApiFeedback.show(context, 'Erro ao registrar venda: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
    if (_cart.isEmpty) return;
    final received = double.tryParse(_received.text.replaceAll(',', '.'));
    if (_paymentMethod == 'cash' && (received == null || received < _total)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o valor recebido para calcular o troco.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final cpf = _cpfController.text.trim();
      final result = await _api.postAuthorized(
        '/partners/parking-management/${widget.parkingId}/convenience-sales',
        {
          'items': _cart.entries
              .map(
                (entry) => {
                  'product_id': entry.key,
                  'quantity': entry.value,
                  'discount_percent': _discounts[entry.key] ?? 0.0,
                },
              )
              .toList(),
          'payment_method': _paymentMethod,
          if (received != null) 'cash_received': received,
          if (cpf.isNotEmpty) 'customer_cpf': cpf,
        },
        await _token(),
      );
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _discounts.clear();
        _received.clear();
        _cpfController.clear();
      });

      // Enriquecer itens com dados de produtos para o comprovante
      final saleItems = (result['items'] as List<dynamic>? ?? []);
      final enrichedItems = saleItems.map((it) {
        final pid = it['product_id'] as String?;
        final prod = _products.firstWhere(
          (p) => p['id'] == pid,
          orElse: () => <String, dynamic>{},
        );
        return {
          'product_name': prod['name'] ?? 'Produto',
          'quantity': it['quantity'],
          'total_price': it['total_price'] ?? ((prod['price'] as num? ?? 0) * (it['quantity'] as num? ?? 1)),
        };
      }).toList();
      result['items'] = enrichedItems;

      if (_paymentMethod == 'pix' && mounted) {
        await showDialog<void>(
          context: context,
          useRootNavigator: true,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Pix simulado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Use este QR Code apenas para simulação local.'),
                const SizedBox(height: 12),
                QrImageView(
                  data: 'PARKHERE-MOCK-PIX-${result['id']}-${result['total_amount']}',
                  size: 220,
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
                child: const Text('Prosseguir'),
              ),
            ],
          ),
        );
      }

      if (mounted) {
        await _showReceiptDialog(result);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancelSale(Map<String, dynamic> sale) async {
    final saleId = sale['id'] as String;
    final reasonController = TextEditingController();
    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Venda'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Venda: #${saleId.substring(saleId.length > 6 ? saleId.length - 6 : 0)}'),
              Text('Valor: R\$ ${(sale['total_amount'] as num? ?? 0).toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Motivo do cancelamento *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha do gestor (se necessário)',
                  helperText: 'Obrigatória caso o operador não tenha permissão.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Informe o motivo do cancelamento.')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirmar Cancelamento'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final token = await _token();
      final body = <String, dynamic>{
        'reason': reasonController.text.trim(),
        if (passwordController.text.trim().isNotEmpty)
          'manager_password': passwordController.text.trim(),
      };

      await _api.postAuthorized(
        '/partners/parking-management/${widget.parkingId}/convenience-sales/$saleId/cancel',
        body,
        token,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venda cancelada com sucesso! Estoque estornado.')),
      );
      _loadSalesHistory();
      _loadProducts(); // recarrega estoque atualizado
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao cancelar venda: $e')),
        );
      }
    }
  }

  Future<void> _loadBleedsHistory() async {
    setState(() => _loadingBleeds = true);
    try {
      final token = await _token();
      final result = await _api.getAuthorized(
        '/parkings/${widget.parkingId}/cash-bleeds?limit=50',
        token,
      );
      if (!mounted) return;
      setState(() {
        _bleedsHistory = result.whereType<Map<String, dynamic>>().toList();
        _loadingBleeds = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingBleeds = false);
    }
  }

  Future<void> _showCashBleedDialog() async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    bool isSavingBleed = false;

    String operatorDisplay = 'Operador do Turno';
    try {
      final tokens = await LocalStorageService().getTokens();
      if (tokens['user_email'] != null && tokens['user_email']!.isNotEmpty) {
        operatorDisplay = tokens['user_email']!;
      }
    } catch (_) {}

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.money_off, color: Colors.orange),
              SizedBox(width: 8),
              Text('Sangria de Caixa'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Responsável: $operatorDisplay',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A sangria retira valores em dinheiro da gaveta para cofre, depósito ou despesa imediata.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: r'Valor da retirada (R$) *',
                    prefixText: r'R$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo da sangria *',
                    hintText: 'Ex: Recolhimento para cofre / depósito',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Observações adicionais (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSavingBleed ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
              onPressed: isSavingBleed
                  ? null
                  : () async {
                      final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
                      final reason = reasonController.text.trim();
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Informe um valor válido para a sangria.')),
                        );
                        return;
                      }
                      if (reason.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Informe o motivo da sangria.')),
                        );
                        return;
                      }

                      setDialogState(() => isSavingBleed = true);
                      try {
                        final token = await _token();
                        final res = await _api.postAuthorized(
                          '/parkings/${widget.parkingId}/cash-bleed',
                          {
                            'amount': amount,
                            'reason': reason,
                            if (notesController.text.trim().isNotEmpty)
                              'notes': notesController.text.trim(),
                          },
                          token,
                        );

                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);

                        if (mounted) {
                          await showDialog<void>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Sangria Concluída'),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Valor retirado: R\$ ${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('Operador: ${res['operator_name'] ?? operatorDisplay}'),
                                  Text('Motivo: $reason'),
                                  const SizedBox(height: 8),
                                  const Divider(),
                                  const Text('Comprovante emitido e registrado no turno.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(context, rootNavigator: true).pop(), child: const Text('OK')),
                              ],
                            ),
                          );
                        }
                        _loadBleedsHistory();
                      } catch (e) {
                        setDialogState(() => isSavingBleed = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erro ao efetuar sangria: $e')),
                          );
                        }
                      }
                    },
              icon: isSavingBleed
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: const Text('Confirmar Sangria'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Caixa · ${widget.parkingName}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade900,
                side: BorderSide(color: Colors.orange.shade300),
                backgroundColor: Colors.orange.shade50,
              ),
              onPressed: _showCashBleedDialog,
              icon: const Icon(Icons.money_off, size: 16),
              label: const Text('Sangria', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.point_of_sale), text: 'Frente de Caixa'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Movimentações'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPosTab(),
          _buildSalesHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildPosTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final products = _filteredProducts;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final catalog = _catalog(products);
        final cart = _cartPanel();
        return wide
            ? Row(
                children: [
                  Expanded(child: catalog),
                  SizedBox(width: 380, child: cart),
                ],
              )
            : Column(
                children: [
                  Expanded(child: catalog),
                  SizedBox(height: 340, child: cart),
                ],
              );
      },
    );
  }

  Widget _buildSalesHistoryTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            selected: {_historySubTab},
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Vendas'),
                icon: Icon(Icons.receipt_long),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Sangrias'),
                icon: Icon(Icons.money_off),
              ),
            ],
            onSelectionChanged: (newSelection) {
              setState(() {
                _historySubTab = newSelection.first;
              });
              if (_historySubTab == 0) {
                _loadSalesHistory();
              } else {
                _loadBleedsHistory();
              }
            },
          ),
        ),
        Expanded(
          child: _historySubTab == 0 ? _buildSalesList() : _buildBleedsList(),
        ),
      ],
    );
  }

  Widget _buildBleedsList() {
    if (_loadingBleeds) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_bleedsHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.money_off_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Nenhuma sangria registrada recentemente.'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadBleedsHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadBleedsHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _bleedsHistory.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final bleed = _bleedsHistory[index];
          final amount = (bleed['amount'] as num? ?? 0).toDouble();
          final reason = bleed['reason'] as String? ?? 'Sangria de caixa';
          final notes = bleed['notes'] as String?;
          final operatorName = bleed['operator_name'] as String? ?? 'Operador';
          final createdAt = bleed['created_at'] != null ? DateTime.tryParse(bleed['created_at'] as String) : null;
          final dateStr = createdAt != null
              ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
              : '';

          return Card(
            elevation: 1,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                foregroundColor: Colors.orange.shade900,
                child: const Icon(Icons.money_off),
              ),
              title: Text('R\$ ${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Motivo: $reason', style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text('Responsável: $operatorName · $dateStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (notes != null && notes.isNotEmpty)
                    Text('Obs: $notes', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSalesList() {
    if (_loadingSales) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_salesHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Nenhuma venda registrada recentemente.'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadSalesHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSalesHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _salesHistory.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final sale = _salesHistory[index];
          final isCancelled = sale['status'] == 'cancelled';
          final total = (sale['total_amount'] as num? ?? 0).toDouble();
          final discount = (sale['discount_total'] as num? ?? 0).toDouble();
          final items = (sale['items'] as List<dynamic>? ?? []);
          final cpf = sale['customer_cpf'] as String?;
          final saleId = sale['id'] as String? ?? '';
          final shortId = saleId.length > 6 ? saleId.substring(saleId.length - 6) : saleId;
          final createdAt = sale['created_at'] != null ? DateTime.tryParse(sale['created_at'] as String) : null;
          final dateStr = createdAt != null
              ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
              : '';

          return Card(
            elevation: 1,
            color: isCancelled ? Colors.grey.shade100 : null,
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: isCancelled ? Colors.red.shade100 : Colors.green.shade100,
                foregroundColor: isCancelled ? Colors.red : Colors.green,
                child: Icon(isCancelled ? Icons.cancel : Icons.check),
              ),
              title: Row(
                children: [
                  Text('#$shortId · R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Chip(
                    label: Text(
                      isCancelled ? 'CANCELADA' : 'CONCLUÍDA',
                      style: TextStyle(fontSize: 10, color: isCancelled ? Colors.red : Colors.green),
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: isCancelled ? Colors.red.shade50 : Colors.green.shade50,
                  ),
                ],
              ),
              subtitle: Text(
                '$dateStr · ${_paymentLabel(sale['payment_method'] as String? ?? '')}'
                '${cpf != null && cpf.isNotEmpty ? ' · CPF: $cpf' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const Text('Itens da venda:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text('${item['quantity']}x ${item['product_name'] ?? 'Produto'}'),
                              const Spacer(),
                              Text('R\$ ${(item['total_price'] as num? ?? 0).toStringAsFixed(2)}'),
                            ],
                          ),
                        ),
                      if (discount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Desconto concedido:', style: TextStyle(color: Colors.green)),
                            const Spacer(),
                            Text('- R\$ ${discount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green)),
                          ],
                        ),
                      ],
                      if (isCancelled && sale['cancel_reason'] != null) ...[
                        const SizedBox(height: 8),
                        Text('Motivo do cancelamento: ${sale['cancel_reason']}', style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic)),
                      ],
                      if (!isCancelled) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showReceiptDialog(sale),
                              icon: const Icon(Icons.receipt_long, size: 18),
                              label: const Text('Comprovante'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              onPressed: () => _cancelSale(sale),
                              icon: const Icon(Icons.cancel_outlined, size: 18),
                              label: const Text('Cancelar'),
                            ),
                          ],
                        ),
                      ],
                      if (isCancelled) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () => _showReceiptDialog(sale),
                            icon: const Icon(Icons.receipt_long_outlined, size: 18),
                            label: const Text('Ver Comprovante'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _catalog(List<Map<String, dynamic>> products) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Buscar por nome ou código de barras',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: OutlinedButton.icon(
            onPressed: () async {
              final barcode = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
              );
              if (barcode == null || !mounted) return;
              setState(() {
                _search.text = barcode;
              });
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Ler com câmera'),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: Builder(
          builder: (context) {
            final grouped = <String, List<Map<String, dynamic>>>{};
            for (final product in products) {
              final category = (product['category'] as String?)?.trim();
              grouped
                  .putIfAbsent(
                    category == null || category.isEmpty
                        ? 'Sem categoria'
                        : category,
                    () => <Map<String, dynamic>>[],
                  )
                  .add(product);
            }
            final children = <Widget>[];
            for (final entry in grouped.entries) {
              children.add(
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              );
              for (final product in entry.value) {
                children.add(_productTile(product));
              }
            }
            return ListView(children: children);
          },
        ),
      ),
    ],
  );

  Widget _productTile(Map<String, dynamic> product) {
    final id = product['id'] as String;
    final quantity = _cart[id] ?? 0;
    final discount = _discounts[id] ?? 0.0;
    final price = (product['price'] as num? ?? 0).toDouble();

    return ListTile(
      title: Text(product['name'] as String? ?? ''),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${product['barcode'] ?? 'Sem código'} · R\$ ${price.toStringAsFixed(2)}'
            '${product['stock_quantity'] != null ? ' · Est: ${product['stock_quantity']}' : ''}',
          ),
          if (quantity > 0 && discount > 0)
            Text(
              'Desconto: ${discount.toStringAsFixed(0)}% (R\$ ${(price * (1 - discount / 100)).toStringAsFixed(2)} un)',
              style: const TextStyle(color: Colors.green, fontSize: 12),
            ),
        ],
      ),
      trailing: quantity == 0
          ? IconButton(
              icon: const Icon(Icons.add_shopping_cart),
              onPressed: () => setState(() => _cart[id] = 1),
            )
          : Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.percent, size: 20),
                  tooltip: 'Aplicar desconto',
                  color: discount > 0 ? Colors.green : null,
                  onPressed: () => _setDiscount(id),
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => setState(() {
                    if (quantity == 1) {
                      _cart.remove(id);
                      _discounts.remove(id);
                    } else {
                      _cart[id] = quantity - 1;
                    }
                  }),
                ),
                Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() => _cart[id] = quantity + 1),
                ),
              ],
            ),
    );
  }

  Widget _cartPanel() => Card(
    margin: const EdgeInsets.all(12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Venda atual',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_cart.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    _cart.clear();
                    _discounts.clear();
                  }),
                  child: const Text('Limpar', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
          Text(
            'Total: R\$ ${_total.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
          ),
          if (_totalDiscount > 0)
            Text(
              'Desconto: - R\$ ${_totalDiscount.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 8),
          if (_cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade800),
                onPressed: _setGlobalDiscount,
                icon: const Icon(Icons.percent, size: 18),
                label: Text(
                  _totalDiscount > 0
                      ? 'Desconto Geral (- R\$ ${_totalDiscount.toStringAsFixed(2)})'
                      : 'Aplicar Desconto Geral',
                ),
              ),
            ),
          TextField(
            controller: _cpfController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'CPF do Cliente (opcional)',
              prefixIcon: Icon(Icons.badge_outlined),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _paymentMethod,
            decoration: const InputDecoration(
              labelText: 'Pagamento',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Dinheiro')),
              DropdownMenuItem(value: 'pix', child: Text('Pix')),
              DropdownMenuItem(
                value: 'credit_card',
                child: Text('Cartão de crédito'),
              ),
              DropdownMenuItem(
                value: 'debit_card',
                child: Text('Cartão de débito'),
              ),
            ],
            onChanged: (value) =>
                setState(() => _paymentMethod = value ?? 'cash'),
          ),
          if (_paymentMethod == 'cash') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _received,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Valor recebido',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (double.tryParse(_received.text.replaceAll(',', '.')) != null &&
                double.tryParse(_received.text.replaceAll(',', '.'))! >= _total)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Troco: R\$ ${(double.parse(_received.text.replaceAll(',', '.')) - _total).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.green),
                  ),
                ),
              ),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed: (_saving || _cart.isEmpty) ? null : _finishSale,
            icon: const Icon(Icons.point_of_sale),
            label: Text(_saving ? 'Registrando...' : 'Finalizar venda (R\$ ${_total.toStringAsFixed(2)})'),
          ),
        ],
      ),
    ),
  );

  String _paymentLabel(String method) {
    return switch (method) {
      'cash' => 'Dinheiro',
      'pix' => 'Pix',
      'credit_card' => 'Cartão de Crédito',
      'debit_card' => 'Cartão de Débito',
      _ => method,
    };
  }
}
