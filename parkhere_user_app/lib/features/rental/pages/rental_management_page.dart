import 'package:flutter/material.dart';

import '../../../core/services/local_storage_service.dart';
import '../services/rental_service.dart';

/// Operação da locadora pelo gestor. O módulo usa endpoints próprios e não
/// altera mapa, vagas ou reservas do estacionamento.
class RentalManagementPage extends StatefulWidget {
  const RentalManagementPage({super.key});

  @override
  State<RentalManagementPage> createState() => _RentalManagementPageState();
}

class _RentalManagementPageState extends State<RentalManagementPage> {
  final _service = RentalService();
  late Future<List<Map<String, dynamic>>> _future;
  String? _token;
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    _token = (await LocalStorageService().getTokens())['access'];
    if (_token == null) throw Exception('Sessão expirada.');
    final companies = await _service.companies(_token!);
    if (_selected != null) {
      final id = _selected!['id'];
      _selected = companies.where((item) => item['id'] == id).firstOrNull;
    }
    _selected ??= companies.firstOrNull;
    return companies;
  }

  Future<void> _createCompany() async {
    final result = await _showCompanyDialog();
    if (result == null || _token == null) return;
    try {
      await _service.createCompany(token: _token!, name: result.name, address: result.address, cnpj: result.cnpj);
      if (mounted) setState(() => _future = _load());
    } catch (error) {
      if (mounted) _message('Não foi possível criar a locadora: $error');
    }
  }

  Future<void> _createVehicle() async {
    final company = _selected;
    if (company == null || _token == null) return;
    final groups = await _service.groups(company['id'] as String, _token!);
    final result = await _showVehicleDialog(groups);
    if (result == null) return;
    try {
      await _service.createVehicle(
        companyId: company['id'] as String,
        token: _token!,
        vehicleType: result.type,
        brand: result.brand,
        model: result.model,
        pricePerDay: result.price,
        year: result.year,
        groupId: result.groupId,
        photoUrls: result.photoUrls,
        specifications: result.specifications,
      );
      if (mounted) setState(() => _future = _load());
    } catch (error) {
      if (mounted) _message('Não foi possível cadastrar o veículo: $error');
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão da locadora'),
        actions: [IconButton(onPressed: () => setState(() => _future = _load()), icon: const Icon(Icons.refresh))],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${snapshot.error}')));
          final companies = snapshot.data ?? const [];
          if (companies.isEmpty) return Center(child: FilledButton.icon(onPressed: _createCompany, icon: const Icon(Icons.add_business), label: const Text('Cadastrar locadora')));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                value: _selected?['id'] as String?,
                decoration: const InputDecoration(labelText: 'Unidade de locação', border: OutlineInputBorder()),
                items: [for (final item in companies) DropdownMenuItem(value: item['id'] as String, child: Text(item['name'] as String? ?? 'Locadora'))],
                onChanged: (id) => setState(() => _selected = companies.firstWhere((item) => item['id'] == id)),
              ),
              const SizedBox(height: 16),
              Row(children: [Text('Frota', style: Theme.of(context).textTheme.titleLarge), const Spacer(), FilledButton.icon(onPressed: _createVehicle, icon: const Icon(Icons.directions_car), label: const Text('Novo veículo'))]),
              const SizedBox(height: 8),
              if (_selected != null) _FleetList(companyId: _selected!['id'] as String, service: _service, token: _token!),
              const SizedBox(height: 20),
              OutlinedButton.icon(onPressed: _createCompany, icon: const Icon(Icons.add_business), label: const Text('Adicionar unidade de locação')),
            ],
          );
        },
      ),
    );
  }

  Future<_CompanyForm?> _showCompanyDialog() async {
    final name = TextEditingController();
    final address = TextEditingController();
    final cnpj = TextEditingController();
    return showDialog<_CompanyForm>(context: context, builder: (context) => AlertDialog(
      title: const Text('Nova unidade de locação'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')), TextField(controller: address, decoration: const InputDecoration(labelText: 'Endereço')), TextField(controller: cnpj, decoration: const InputDecoration(labelText: 'CNPJ (opcional)'))])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () { if (name.text.trim().length >= 2) Navigator.pop(context, _CompanyForm(name.text, address.text, cnpj.text)); }, child: const Text('Salvar'))],
    ));
  }

  Future<_VehicleForm?> _showVehicleDialog(List<Map<String, dynamic>> groups) async {
    final brand = TextEditingController();
    final model = TextEditingController();
    final year = TextEditingController();
    final price = TextEditingController();
    var type = 'car';
    String? groupId = groups.firstOrNull?['id'] as String?;
    List<Map<String, dynamic>> suggestions = const [];
    List<String> photoUrls = const [];
    Map<String, dynamic> specifications = const {};
    return showDialog<_VehicleForm>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('Novo veículo da frota'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (groups.isNotEmpty) DropdownButtonFormField<String>(initialValue: groupId, decoration: const InputDecoration(labelText: 'Grupo do veículo'), items: [for (final group in groups) DropdownMenuItem(value: group['id'] as String, child: Text(group['name'] as String? ?? 'Grupo'))], onChanged: (value) { final selected = groups.firstWhere((group) => group['id'] == value); setDialogState(() { groupId = value; type = selected['vehicle_type'] as String? ?? 'car'; if (price.text.isEmpty && selected['suggested_price_per_day'] != null) price.text = '${selected['suggested_price_per_day']}'; }); }),
        DropdownButtonFormField<String>(initialValue: type, decoration: const InputDecoration(labelText: 'Tipo'), items: const [DropdownMenuItem(value: 'car', child: Text('Carro')), DropdownMenuItem(value: 'suv', child: Text('SUV')), DropdownMenuItem(value: 'pickup', child: Text('Picape')), DropdownMenuItem(value: 'van', child: Text('Van')), DropdownMenuItem(value: 'motorcycle', child: Text('Motocicleta')), DropdownMenuItem(value: 'electric_car', child: Text('Carro elétrico'))], onChanged: (value) => setDialogState(() => type = value ?? 'car')),
        TextField(controller: brand, decoration: const InputDecoration(labelText: 'Marca')),
        TextField(controller: model, decoration: const InputDecoration(labelText: 'Modelo')),
        TextField(controller: year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ano')),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () async { final parsedYear = int.tryParse(year.text); if (brand.text.trim().isEmpty || parsedYear == null) return; try { final found = await _service.catalogModels(make: brand.text, year: parsedYear, vehicleType: type, token: _token!); setDialogState(() => suggestions = found); } catch (_) {} }, icon: const Icon(Icons.search), label: const Text('Buscar modelo e especificações'))),
        if (suggestions.isNotEmpty) DropdownButtonFormField<Map<String, dynamic>>(initialValue: suggestions.first, decoration: const InputDecoration(labelText: 'Modelo encontrado'), items: [for (final item in suggestions) DropdownMenuItem(value: item, child: Text(item['model'] as String? ?? 'Modelo'))], onChanged: (value) { if (value != null) setDialogState(() { model.text = value['model'] as String? ?? model.text; photoUrls = [for (final url in (value['photo_urls'] as List<dynamic>? ?? const [])) url.toString()]; specifications = (value['specifications'] as Map<String, dynamic>?) ?? const {}; }); }),
        if (photoUrls.isNotEmpty) Align(alignment: Alignment.centerLeft, child: Text('${photoUrls.length} foto(s) sugerida(s) encontrada(s). Você poderá substituir por fotos próprias após o cadastro.', style: Theme.of(context).textTheme.bodySmall)),
        TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Diária (R\$)')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () { final parsed = double.tryParse(price.text.replaceAll(',', '.')); if (brand.text.isNotEmpty && model.text.isNotEmpty && parsed != null && parsed > 0) Navigator.pop(context, _VehicleForm(type, brand.text, model.text, parsed, int.tryParse(year.text), groupId, photoUrls, specifications)); }, child: const Text('Salvar'))],
    )));
  }
}

class _FleetList extends StatelessWidget {
  final String companyId; final RentalService service; final String token;
  const _FleetList({required this.companyId, required this.service, required this.token});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(future: service.vehicles(companyId, token), builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
    if (snapshot.hasError) return Text('Erro ao carregar a frota: ${snapshot.error}');
    final vehicles = snapshot.data ?? const [];
    if (vehicles.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Nenhum veículo cadastrado.')));
    return Column(children: [for (final vehicle in vehicles) Card(child: ListTile(leading: const Icon(Icons.directions_car_outlined), title: Text('${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'), subtitle: Text('${vehicle['vehicle_type'] ?? 'car'} • ${vehicle['year'] ?? '-'}'), trailing: Text('R\$ ${vehicle['price_per_day'] ?? '-'}')))]);
  });
}

class _CompanyForm { final String name, address, cnpj; const _CompanyForm(this.name, this.address, this.cnpj); }
class _VehicleForm { final String type, brand, model; final double price; final int? year; final String? groupId; final List<String> photoUrls; final Map<String, dynamic> specifications; const _VehicleForm(this.type, this.brand, this.model, this.price, this.year, this.groupId, this.photoUrls, this.specifications); }
