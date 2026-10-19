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

class _ConveniencePosPageState extends State<ConveniencePosPage> {
  final _api = ApiService();
  final _search = TextEditingController();
  final _received = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  final Map<String, int> _cart = {};
  String _paymentMethod = 'cash';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _search.dispose();
    _received.dispose();
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

  List<Map<String, dynamic>> get _filteredProducts {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _products;
    return _products.where((item) {
      final name = '${item['name']} ${item['barcode'] ?? ''}'.toLowerCase();
      return name.contains(query);
    }).toList();
  }

  double get _total => _cart.entries.fold(0, (sum, entry) {
    final product = _products.firstWhere((item) => item['id'] == entry.key);
    return sum + ((product['price'] as num? ?? 0).toDouble() * entry.value);
  });

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
      final result = await _api.postAuthorized(
        '/partners/parking-management/${widget.parkingId}/convenience-sales',
        {
          'items': _cart.entries
              .map(
                (entry) => {'product_id': entry.key, 'quantity': entry.value},
              )
              .toList(),
          'payment_method': _paymentMethod,
          if (received != null) 'cash_received': received,
        },
        await _token(),
      );
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _received.clear();
      });
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Venda registrada'),
          content: Text(
            'Total: R\$ ${(result['total_amount'] as num? ?? 0).toStringAsFixed(2)}\n'
            'Troco: R\$ ${(result['change_amount'] as num? ?? 0).toStringAsFixed(2)}',
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

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;
    return Scaffold(
      appBar: AppBar(title: Text('Caixa · ${widget.parkingName}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final catalog = _catalog(products);
                final cart = _cartPanel();
                return wide
                    ? Row(
                        children: [
                          Expanded(child: catalog),
                          SizedBox(width: 360, child: cart),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: catalog),
                          SizedBox(height: 300, child: cart),
                        ],
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
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
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
    return ListTile(
      title: Text(product['name'] as String? ?? ''),
      subtitle: Text(
        '${product['barcode'] ?? 'Sem código'} · R\$ ${(product['price'] as num? ?? 0).toStringAsFixed(2)}',
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
                  icon: const Icon(Icons.remove),
                  onPressed: () => setState(
                    () => quantity == 1
                        ? _cart.remove(id)
                        : _cart[id] = quantity - 1,
                  ),
                ),
                Text('$quantity'),
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
          const Text(
            'Venda atual',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            'Total: R\$ ${_total.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _paymentMethod,
            decoration: const InputDecoration(labelText: 'Pagamento'),
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
              decoration: const InputDecoration(labelText: 'Valor recebido'),
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
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed: _saving ? null : _finishSale,
            icon: const Icon(Icons.point_of_sale),
            label: Text(_saving ? 'Registrando...' : 'Finalizar venda'),
          ),
        ],
      ),
    ),
  );
}
