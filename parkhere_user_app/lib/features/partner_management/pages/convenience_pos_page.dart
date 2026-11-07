import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  bool _loadingSales = false;

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

  Future<void> _finishSale() async {
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

      final totalPaid = (result['total_amount'] as num? ?? 0).toDouble();
      final changeVal = (result['change_amount'] as num? ?? 0).toDouble();
      final discountVal = (result['discount_total'] as num? ?? 0).toDouble();

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Venda registrada!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total: R\$ ${totalPaid.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              if (discountVal > 0)
                Text(
                  'Desconto aplicado: R\$ ${discountVal.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.green),
                ),
              if (_paymentMethod == 'cash')
                Text('Troco: R\$ ${changeVal.toStringAsFixed(2)}'),
              if (cpf.isNotEmpty) Text('CPF no comprovante: $cpf'),
              const Divider(height: 20),
              const Text(
                'Comprovante não fiscal emitido com sucesso.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (_paymentMethod == 'pix' && mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
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
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Caixa · ${widget.parkingName}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.point_of_sale), text: 'Frente de Caixa'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Últimas Vendas'),
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: () => _cancelSale(sale),
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('Cancelar Venda'),
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
