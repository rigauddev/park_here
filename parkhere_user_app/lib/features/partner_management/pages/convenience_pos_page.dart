// Convenience POS Page - cleaned implementation
// This file implements a POS screen for convenience sales within the parking management module.
// It includes product loading, cart management, discounts, cash handling, and receipt generation.

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
    Key? key,
    required this.parkingId,
    required this.parkingName,
  }) : super(key: key);

  @override
  State<ConveniencePosPage> createState() => _ConveniencePosPageState();
}

class _ConveniencePosPageState extends State<ConveniencePosPage>
    with SingleTickerProviderStateMixin {
  // Services
  final ApiService _api = ApiService();

  // Controllers
  final TextEditingController _search = TextEditingController();
  final TextEditingController _received = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();

  // UI state
  late TabController _tabController;
  bool _loading = true;
  bool _saving = false;
  String _paymentMethod = 'cash';

  // Data structures
  List<Map<String, dynamic>> _products = [];
  final Map<String, int> _cart = {};
  final Map<String, double> _discounts = {};
  bool _loadingSales = false;
  bool _loadingBleeds = false;
  List<Map<String, dynamic>> _salesHistory = [];
  List<Map<String, dynamic>> _bleedsHistory = [];
  int _historySubTab = 0; // 0 = sales, 1 = cash bleeds

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

  // ---------------------------------------------------------------------
  // Data loading helpers
  // ---------------------------------------------------------------------
  Future<void> _loadProducts() async {
    try {
      final result = await _api.getAuthorized(
        '/partners/parking-management/${widget.parkingId}/conveniences',
        await _token(),
      );
      if (!mounted) return;
      setState(() {
        _products = List<Map<String, dynamic>>.from(result);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar produtos: $e')),
        );
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
        _salesHistory = List<Map<String, dynamic>>.from(result);
        _loadingSales = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingSales = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar histórico de vendas: $e')),
        );
      }
    }
  }

  Future<void> _loadBleedsHistory() async {
    setState(() => _loadingBleeds = true);
    try {
      final result = await _api.getAuthorized(
        '/parkings/${widget.parkingId}/cash-bleeds?limit=50',
        await _token(),
      );
      if (!mounted) return;
      setState(() {
        _bleedsHistory = List<Map<String, dynamic>>.from(result);
        _loadingBleeds = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingBleeds = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar histórico de sangrias: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // Computed properties
  // ---------------------------------------------------------------------
  List<Map<String, dynamic>> get _filteredProducts {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _products;
    return _products.where((item) {
      final name = '${item['name']} ${item['barcode'] ?? ''}'.toLowerCase();
      return name.contains(query);
    }).toList();
  }

  double get _total {
    return _cart.entries.fold(0.0, (sum, entry) {
      final product = _products.firstWhere(
        (p) => p['id'] == entry.key,
        orElse: () => {},
      );
      final price = (product['price'] as num?)?.toDouble() ?? 0.0;
      final discount = _discounts[entry.key] ?? 0.0;
      final itemTotal = price * entry.value * (1 - discount / 100);
      return sum + itemTotal;
    });
  }

  double get _rawTotal {
    return _cart.entries.fold(0.0, (sum, entry) {
      final product = _products.firstWhere(
        (p) => p['id'] == entry.key,
        orElse: () => {},
      );
      final price = (product['price'] as num?)?.toDouble() ?? 0.0;
      return sum + price * entry.value;
    });
  }

  double get _totalDiscount => _rawTotal - _total;

  // ---------------------------------------------------------------------
  // UI helpers for discounts
  // ---------------------------------------------------------------------
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
                  const SnackBar(
                    content: Text('Porcentagem inválida (0 a 100).'),
                  ),
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
      builder: (ctx) => AlertDialog(
        title: const Text('Desconto Geral na Venda'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informe a porcentagem de desconto a aplicar em todos os itens do carrinho:',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Desconto Geral (%)',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0.0),
            child: const Text('Zerar Descontos'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text.replaceAll(',', '.'));
              if (val != null && val >= 0 && val <= 100) {
                Navigator.pop(ctx, val);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Porcentagem inválida (0 a 100).'),
                  ),
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

  // ---------------------------------------------------------------------
  // Receipt & printing helpers
  // ---------------------------------------------------------------------
  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Dinheiro';
      case 'card':
        return 'Cartão';
      default:
        return method;
    }
  }

  Future<void> _printThermalReceipt(Map<String, dynamic> sale) async {
    final shortId = ((sale['id'] as String?)?.length ?? 0) > 6
        ? (sale['id'] as String).substring((sale['id'] as String).length - 6)
        : sale['id'] ?? '';
    final total = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
    final discount = (sale['discount_total'] as num?)?.toDouble() ?? 0.0;
    final items = List<Map<String, dynamic>>.from(sale['items'] ?? []);
    final cpf = sale['customer_cpf'] as String?;
    final payment = _paymentLabel(sale['payment_method'] as String? ?? '');
    final createdAt = sale['created_at'] != null
        ? DateTime.tryParse(sale['created_at'] as String)?.toLocal()
        : DateTime.now();
    final dateStr = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '';
    final operatorName =
        sale['operator_name'] as String? ?? 'Operador do Turno';

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          58 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 2 * PdfPageFormat.mm,
        ),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                widget.parkingName.toUpperCase(),
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Center(
              child: pw.Text(
                'COMPROVANTE NAO FISCAL',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                '--------------------------------',
                style: pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.Text('VENDA: #$shortId', style: pw.TextStyle(fontSize: 8)),
            pw.Text('DATA: $dateStr', style: pw.TextStyle(fontSize: 8)),
            pw.Text(
              'OPERADOR: $operatorName',
              style: pw.TextStyle(fontSize: 8),
            ),
            if (cpf != null && cpf.isNotEmpty)
              pw.Text('CPF CLIENTE: $cpf', style: pw.TextStyle(fontSize: 8)),
            pw.Center(
              child: pw.Text(
                '--------------------------------',
                style: pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'ITEM',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'TOTAL (R\$)',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            for (final item in items)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      '${item['quantity']}x ${item['product_name'] ?? 'Produto'}',
                      style: pw.TextStyle(fontSize: 8),
                      maxLines: 1,
                    ),
                  ),
                  pw.Text(
                    (item['total_price'] as num?)?.toStringAsFixed(2) ?? '0.00',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            pw.Center(
              child: pw.Text(
                '--------------------------------',
                style: pw.TextStyle(fontSize: 8),
              ),
            ),
            if (discount > 0)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('DESCONTO:', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    '- R\$ ${discount.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL A PAGAR:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'R\$ ${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Text('FORMA PAGTO: $payment', style: pw.TextStyle(fontSize: 8)),
            if (((sale['change_amount'] as num?) ?? 0) > 0)
              pw.Text(
                'TROCO: R\$ ${((sale['change_amount'] as num?) ?? 0).toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 8),
              ),
            pw.Center(
              child: pw.Text(
                '--------------------------------',
                style: pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'OBRIGADO PELA PREFERENCIA!\nVOLTE SEMPRE',
                style: pw.TextStyle(fontSize: 7),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Comprovante_Venda_$shortId.pdf',
    );
  }

  Future<void> _shareReceiptWhatsApp(Map<String, dynamic> sale) async {
    final shortId = ((sale['id'] as String?)?.length ?? 0) > 6
        ? (sale['id'] as String).substring((sale['id'] as String).length - 6)
        : sale['id'] ?? '';
    final total = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
    final discount = (sale['discount_total'] as num?)?.toDouble() ?? 0.0;
    final items = List<Map<String, dynamic>>.from(sale['items'] ?? []);
    final cpf = sale['customer_cpf'] as String?;
    final payment = _paymentLabel(sale['payment_method'] as String? ?? '');
    final createdAt = sale['created_at'] != null
        ? DateTime.tryParse(sale['created_at'] as String)?.toLocal()
        : DateTime.now();
    final dateStr = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '';
    final operatorName =
        sale['operator_name'] as String? ?? 'Operador do Turno';

    final sb = StringBuffer();
    sb.writeln('*${widget.parkingName.toUpperCase()}*');
    sb.writeln('*COMPROVANTE NÃO FISCAL*');
    sb.writeln('--------------------------------');
    sb.writeln('📋 *Venda:* #$shortId');
    sb.writeln('📅 *Data:* $dateStr');
    sb.writeln('👤 *Operador:* $operatorName');
    if (cpf != null && cpf.isNotEmpty) sb.writeln('🪪 *CPF Cliente:* $cpf');
    sb.writeln('--------------------------------');
    sb.writeln('*ITENS:*');
    for (final item in items) {
      final name = item['product_name'] ?? 'Produto';
      final q = item['quantity'];
      final p = (item['total_price'] as num?)?.toStringAsFixed(2) ?? '0.00';
      sb.writeln(' • ${q}x $name: R\$ $p');
    }
    sb.writeln('--------------------------------');
    if (discount > 0)
      sb.writeln('Desconto: - R\$ ${discount.toStringAsFixed(2)}');
    sb.writeln('💰 *TOTAL:* R\$ ${total.toStringAsFixed(2)}');
    sb.writeln('💳 *Pagamento:* $payment');
    if (((sale['change_amount'] as num?) ?? 0) > 0) {
      sb.writeln(
        'Troco: R\$ ${((sale['change_amount'] as num?) ?? 0).toStringAsFixed(2)}',
      );
    }
    sb.writeln('--------------------------------');
    sb.writeln('Agradecemos a sua preferência!');

    final url = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(sb.toString())}',
    );
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
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Comprovante #${sale['id'] ?? ''}'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Simplified receipt view – can be expanded later.
              Text(
                'Total: R\$ ${(sale['total_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Sale finalization
  // ---------------------------------------------------------------------
  Future<void> _finishSale() async {
    if (_cart.isEmpty) return;
    final received =
        double.tryParse(_received.text.replaceAll(',', '.')) ?? 0.0;
    if (_paymentMethod == 'cash' && (received < _total)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor recebido insuficiente.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = {
        'parking_id': widget.parkingId,
        'items': _cart.entries
            .map(
              (e) => {
                'product_id': e.key,
                'quantity': e.value,
                'discount': _discounts[e.key] ?? 0,
              },
            )
            .toList(),
        'payment_method': _paymentMethod,
        'received_amount': received,
        'cpf': _cpfController.text.trim(),
      };
      final result = await _api.postAuthorized(
        '/partners/parking-management/${widget.parkingId}/convenience-sales',
        payload,
        await _token(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Venda concluída com sucesso.')),
        );
        await _printThermalReceipt(result);
        await _showReceiptDialog(result);
        // Reset cart
        setState(() {
          _cart.clear();
          _discounts.clear();
          _received.clear();
          _cpfController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao concluir venda: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------
  // UI Build
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('POS - ${widget.parkingName}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Vendas'),
            Tab(text: 'Sangrias'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildSalesTab(), _buildBleedsTab()],
            ),
    );
  }

  Widget _buildSalesTab() {
    // Placeholder UI – replace with actual product list, cart, etc.
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _search,
            decoration: const InputDecoration(labelText: 'Buscar produto'),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredProducts.length,
              itemBuilder: (ctx, idx) {
                final product = _filteredProducts[idx];
                final id = product['id'] as String? ?? '';
                final name = product['name'] ?? 'Produto';
                final price =
                    (product['price'] as num?)?.toStringAsFixed(2) ?? '0.00';
                final qty = _cart[id] ?? 0;
                return ListTile(
                  title: Text(name),
                  subtitle: Text('R\$ $price'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: qty > 0
                            ? () => setState(() => _cart[id] = qty - 1)
                            : null,
                      ),
                      Text(qty.toString()),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => setState(() => _cart[id] = qty + 1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.discount),
                        onPressed: () => _setDiscount(id),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Total'),
            trailing: Text('R\$ ${_total.toStringAsFixed(2)}'),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _received,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor Recebido',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _cpfController,
                  decoration: const InputDecoration(labelText: 'CPF Cliente'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _paymentMethod,
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Dinheiro')),
                    DropdownMenuItem(value: 'card', child: Text('Cartão')),
                  ],
                  onChanged: (v) =>
                      setState(() => _paymentMethod = v ?? 'cash'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : _finishSale,
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Finalizar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBleedsTab() {
    if (_loadingBleeds) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: _bleedsHistory.length,
      itemBuilder: (ctx, idx) {
        final bleed = _bleedsHistory[idx];
        return ListTile(
          title: Text('Sangria #${bleed['id'] ?? ''}'),
          subtitle: Text(
            'Valor: R\$ ${(bleed['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
          ),
        );
      },
    );
  }
}
