import 'package:flutter/material.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/local_storage_service.dart';

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
      if (!mounted) return;
      setState(() {
        _items = result.whereType<Map<String, dynamic>>().toList();
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
      builder: (_) => const _ConvenienceDialog(),
    );
    if (data == null) return;
    try {
      final token = (await LocalStorageService().getTokens())['access'];
      if (token == null) throw Exception('Sessão expirada.');
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
      appBar: AppBar(title: Text('Conveniência · ${widget.parkingName}')),
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
                      '${item['category'] ?? ''}${item['subcategory'] == null ? '' : ' · ${item['subcategory']}'}\n${item['description'] ?? ''}',
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
  const _ConvenienceDialog();

  @override
  State<_ConvenienceDialog> createState() => _ConvenienceDialogState();
}

class _ConvenienceDialogState extends State<_ConvenienceDialog> {
  final category = TextEditingController();
  final subcategory = TextEditingController();
  final name = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController(text: '0');

  @override
  void dispose() {
    for (final controller in [
      category,
      subcategory,
      name,
      description,
      price,
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
            _field(category, 'Categoria'),
            _field(subcategory, 'Subcategoria (opcional)'),
            _field(name, 'Nome do produto'),
            _field(description, 'Descrição (opcional)'),
            _field(price, 'Preço', keyboard: TextInputType.number),
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
            if (category.text.trim().isEmpty ||
                name.text.trim().isEmpty ||
                value == null ||
                value < 0) {
              return;
            }
            Navigator.pop(context, {
              'category': category.text.trim(),
              'subcategory': subcategory.text.trim().isEmpty
                  ? null
                  : subcategory.text.trim(),
              'name': name.text.trim(),
              'description': description.text.trim().isEmpty
                  ? null
                  : description.text.trim(),
              'price': value,
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
