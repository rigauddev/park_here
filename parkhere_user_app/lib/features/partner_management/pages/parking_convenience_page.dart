import 'package:flutter/material.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/local_storage_service.dart';
import 'convenience_pos_page.dart';

class ParkingConveniencePage extends StatefulWidget {
  final String parkingId;
  final String parkingName;

  const ParkingConveniencePage({
    super.key,
    required this.parkingId,
    required this.parkingName,
  });

  @override
  State<ParkingConveniencePage> createState() => _ParkingConveniencePageState();
}

class _ParkingConveniencePageState extends State<ParkingConveniencePage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = (await LocalStorageService().getTokens())['access'];
      if (token == null) throw Exception('Sessão expirada.');
      final result = await _api.getAuthorized(
        '/partners/parking-management/${widget.parkingId}/conveniences',
        token,
      );
      final categories = await _api.getAuthorized(
        '/partners/parking-management/${widget.parkingId}/convenience-categories',
        token,
      );
      if (!mounted) return;
      setState(() {
        _items = result.whereType<Map<String, dynamic>>().toList();
        _categories = categories.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível carregar os produtos: $error'),
        ),
      );
    }
  }

  Future<void> _add() async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ConvenienceDialog(categories: _categories),
    );
    if (data == null) return;
    try {
      final token = (await LocalStorageService().getTokens())['access'];
      if (token == null) throw Exception('Sessão expirada.');
      if (data['category_id'] == null) {
        final category = await _api.postAuthorized(
          '/partners/parking-management/${widget.parkingId}/convenience-categories',
          {'name': data['category'], 'subcategory': data['subcategory']},
          token,
        );
        data['category_id'] = category['id'];
      }
      await _api.postAuthorized(
        '/partners/parking-management/${widget.parkingId}/conveniences',
        data,
        token,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar o produto: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Conveniência · ${widget.parkingName}'),
        actions: [
          IconButton(
            tooltip: 'Caixa / ponto de venda',
            icon: const Icon(Icons.point_of_sale_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConveniencePosPage(
                  parkingId: widget.parkingId,
                  parkingName: widget.parkingName,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Produto'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text('Nenhum produto cadastrado.'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: _items.length,
              itemBuilder: (_, index) {
                final item = _items[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.shopping_bag_outlined),
                    ),
                    title: Text(item['name'] as String? ?? ''),
                    subtitle: Text(
                      '${item['category'] ?? ''}${item['subcategory'] == null ? '' : ' · ${item['subcategory']}'}\n'
                      '${item['description'] ?? ''}'
                      '${item['stock_quantity'] == null ? '' : '\nEstoque: ${item['stock_quantity']}'}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      'R\$ ${(item['price'] as num? ?? 0).toStringAsFixed(2)}',
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ConvenienceDialog extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  const _ConvenienceDialog({required this.categories});

  @override
  State<_ConvenienceDialog> createState() => _ConvenienceDialogState();
}

class _ConvenienceDialogState extends State<_ConvenienceDialog> {
  final category = TextEditingController();
  final subcategory = TextEditingController();
  final name = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController(text: '0');
  final barcode = TextEditingController();
  final stock = TextEditingController();
  String? categoryId;

  @override
  void dispose() {
    for (final controller in [
      category,
      subcategory,
      name,
      description,
      price,
      barcode,
      stock,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo produto de conveniência'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.categories.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Categoria existente',
                ),
                items: widget.categories.map((item) {
                  final label =
                      '${item['name']}${item['subcategory'] == null ? '' : ' · ${item['subcategory']}'}';
                  return DropdownMenuItem(
                    value: item['id'] as String,
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) => setState(() {
                  categoryId = value;
                  final selected = widget.categories.firstWhere(
                    (item) => item['id'] == value,
                    orElse: () => const <String, dynamic>{},
                  );
                  category.text = selected['name'] as String? ?? '';
                  subcategory.text = selected['subcategory'] as String? ?? '';
                }),
              ),
            _field(category, 'Categoria'),
            _field(subcategory, 'Subcategoria (opcional)'),
            _field(name, 'Nome do produto'),
            _field(description, 'Descrição (opcional)'),
            _field(price, 'Preço', keyboard: TextInputType.number),
            _field(
              barcode,
              'Código de barras (opcional)',
              keyboard: TextInputType.number,
            ),
            _field(
              stock,
              'Estoque (vazio = sem controle)',
              keyboard: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final value = double.tryParse(price.text.replaceAll(',', '.'));
            if (category.text.trim().isEmpty && categoryId == null ||
                name.text.trim().isEmpty ||
                value == null ||
                value < 0) {
              return;
            }
            final categoryName = category.text.trim().isNotEmpty
                ? category.text.trim()
                : (widget.categories.firstWhere(
                            (item) => item['id'] == categoryId,
                            orElse: () => const <String, dynamic>{},
                          )['name']
                          as String? ??
                      '');
            Navigator.pop(context, {
              'category': categoryName,
              'category_id': categoryId,
              'subcategory': subcategory.text.trim().isEmpty
                  ? null
                  : subcategory.text.trim(),
              'name': name.text.trim(),
              'description': description.text.trim().isEmpty
                  ? null
                  : description.text.trim(),
              'price': value,
              'barcode': barcode.text.trim().isEmpty
                  ? null
                  : barcode.text.trim(),
              'stock_quantity': stock.text.trim().isEmpty
                  ? null
                  : int.tryParse(stock.text.trim()),
              'is_active': true,
            });
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
