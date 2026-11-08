import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/services/local_storage_service.dart';
import '../services/rental_service.dart';

/// Operação da locadora pelo gestor. O módulo usa endpoints próprios e não
/// altera mapa, vagas ou reservas do estacionamento.
class RentalManagementPage extends StatefulWidget {
  final bool operatorMode;

  const RentalManagementPage({super.key, this.operatorMode = false});

  @override
  State<RentalManagementPage> createState() => _RentalManagementPageState();
}

class _RentalManagementPageState extends State<RentalManagementPage> {
  final _service = RentalService();
  late Future<_RentalDashboardData> _future;
  String? _token;
  Map<String, dynamic>? _selected;
  String _statusFilter = 'all';
  String _categoryFilter = 'all';
  String _search = '';
  bool _gridView = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_RentalDashboardData> _load() async {
    _token = (await LocalStorageService().getTokens())['access'];
    if (_token == null) throw Exception('Sessão expirada.');
    final companies = await _service.companies(_token!);
    if (_selected != null) {
      final id = _selected!['id'];
      _selected = companies.where((item) => item['id'] == id).firstOrNull;
    }
    _selected ??= companies.firstOrNull;
    if (_selected == null) return _RentalDashboardData(companies: companies);
    final companyId = _selected!['id'] as String;
    final results = await Future.wait([
      _service.vehicles(companyId, _token!),
      _service.groups(companyId, _token!),
      _service.reservations(_token!),
    ]);
    return _RentalDashboardData(
      companies: companies,
      vehicles: results[0] as List<Map<String, dynamic>>,
      groups: results[1] as List<Map<String, dynamic>>,
      reservations: (results[2] as List<Map<String, dynamic>>)
          .where((item) => item['company_id'] == companyId)
          .toList(),
    );
  }

  Future<void> _createCompany() async {
    final result = await _showCompanyDialog();
    if (result == null || _token == null) return;
    try {
      final company = await _service.createCompany(
        token: _token!,
        name: result.name,
        address: result.address,
        cnpj: result.cnpj,
      );
      if (result.logoName != null && result.logoBytes != null) {
        await _service.uploadCompanyLogo(
          companyId: company['id'].toString(),
          token: _token!,
          fileName: result.logoName!,
          bytes: result.logoBytes!,
        );
      }
      if (mounted) setState(() => _future = _load());
    } catch (error) {
      if (mounted) _message('Não foi possível criar o serviço: $error');
    }
  }

  Future<void> _createVehicle() async {
    final company = _selected;
    if (company == null || _token == null) return;
    final groups = await _service.groups(company['id'] as String, _token!);
    final result = await _showVehicleDialog(groups);
    if (result == null) return;
    try {
      final created = await _service.createVehicle(
        companyId: company['id'] as String,
        token: _token!,
        vehicleType: result.type,
        brand: result.brand,
        model: result.model,
        pricePerDay: result.price,
        year: result.year,
        plate: result.plate,
        groupId: result.groupId,
        photoUrls: result.photoUrls,
        specifications: result.specifications,
        manufactureYear: result.manufactureYear,
        crlvCode: result.crlvCode,
        renavam: result.renavam,
        chassis: result.chassis,
      );
      if (result.crlvFileName != null &&
          result.crlvBytes != null &&
          created['id'] != null) {
        await _service.uploadCrlv(
          vehicleId: created['id'].toString(),
          token: _token!,
          fileName: result.crlvFileName!,
          bytes: result.crlvBytes!,
        );
      }
      if (result.ownPhotoName != null &&
          result.ownPhotoBytes != null &&
          created['id'] != null) {
        await _service.uploadVehiclePhoto(
          vehicleId: created['id'].toString(),
          token: _token!,
          fileName: result.ownPhotoName!,
          bytes: result.ownPhotoBytes!,
        );
      }
      if (mounted) _message('Veículo cadastrado com sucesso.');
      if (mounted) setState(() => _future = _load());
    } catch (error) {
      if (mounted) _message('Não foi possível cadastrar o veículo: $error');
    }
  }

  Future<void> _editVehicle(Map<String, dynamic> vehicle) async {
    if (_token == null || _selected == null) return;
    final groups = await _service.groups(_selected!['id'] as String, _token!);
    final result = await _showVehicleDialog(groups, vehicle: vehicle);
    if (result == null) return;
    try {
      await _service.updateVehicle(
        vehicleId: vehicle['id'].toString(),
        token: _token!,
        groupId: result.groupId,
        vehicleType: result.type,
        brand: result.brand,
        model: result.model,
        pricePerDay: result.price,
        year: result.year,
        manufactureYear: result.manufactureYear,
        plate: result.plate,
        crlvCode: result.crlvCode,
        renavam: result.renavam,
        chassis: result.chassis,
        photoUrls: result.photoUrls,
        specifications: result.specifications,
      );
      if (result.crlvFileName != null && result.crlvBytes != null) {
        await _service.uploadCrlv(
          vehicleId: vehicle['id'].toString(),
          token: _token!,
          fileName: result.crlvFileName!,
          bytes: result.crlvBytes!,
        );
      }
      if (result.ownPhotoName != null && result.ownPhotoBytes != null) {
        await _service.uploadVehiclePhoto(
          vehicleId: vehicle['id'].toString(),
          token: _token!,
          fileName: result.ownPhotoName!,
          bytes: result.ownPhotoBytes!,
        );
      }
      if (mounted) {
        _message('Veículo atualizado com sucesso.');
        setState(() => _future = _load());
      }
    } catch (error) {
      if (mounted) _message('Não foi possível atualizar o veículo: $error');
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operação da frota'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _future = _load()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_RentalDashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}'),
              ),
            );
          final data = snapshot.data!;
          final companies = data.companies;
          if (companies.isEmpty)
            return Center(
              child: FilledButton.icon(
                onPressed: _createCompany,
                icon: const Icon(Icons.add_business),
                label: const Text('Cadastrar locadora'),
              ),
            );
          return _dashboard(context, data);
        },
      ),
    );
  }

  Widget _dashboard(BuildContext context, _RentalDashboardData data) {
    final vehicles = data.vehicles.where((vehicle) {
      final status = vehicle['status']?.toString() ?? '';
      final groupId = vehicle['group_id']?.toString();
      final text =
          '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''} ${vehicle['plate'] ?? ''}'
              .toLowerCase();
      return (_statusFilter == 'all' || status == _statusFilter) &&
          (_categoryFilter == 'all' || groupId == _categoryFilter) &&
          (_search.isEmpty || text.contains(_search.toLowerCase()));
    }).toList();
    final available = data.vehicles
        .where((v) => v['status'] == 'available')
        .length;
    final reserved = data.vehicles
        .where((v) => v['status'] == 'reserved')
        .length;
    final maintenance = data.vehicles
        .where((v) => v['status'] == 'maintenance')
        .length;
    final paid = data.reservations
        .where((r) => r['payment_status'] == 'paid')
        .toList();
    final pending = data.reservations
        .where((r) => r['payment_status'] != 'paid')
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = _load()),
          child: ListView(
            padding: EdgeInsets.all(compact ? 16 : 28),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parceiro de locação',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        'Operação da frota',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const Text(
                        'Disponibilidade, reservas e status dos veículos da unidade.',
                      ),
                    ],
                  ),
                  SizedBox(
                    width: compact ? constraints.maxWidth : 300,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selected?['id'] as String?,
                      decoration: const InputDecoration(
                        labelText: 'Unidade',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      items: [
                        for (final item in data.companies)
                          DropdownMenuItem(
                            value: item['id'] as String,
                            child: Text(item['name'] as String? ?? 'Locadora'),
                          ),
                      ],
                      onChanged: (id) {
                        if (id == null) return;
                        setState(() {
                          _selected = data.companies.firstWhere(
                            (item) => item['id'] == id,
                          );
                          _future = _load();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric(
                    label: 'Veículos na frota',
                    value: '${data.vehicles.length}',
                    icon: Icons.directions_car_outlined,
                    color: Colors.blue,
                  ),
                  _Metric(
                    label: 'Disponíveis',
                    value: '$available',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  _Metric(
                    label: 'Em locação',
                    value: '$reserved',
                    icon: Icons.event_available_outlined,
                    color: Colors.indigo,
                  ),
                  _Metric(
                    label: 'Em manutenção',
                    value: '$maintenance',
                    icon: Icons.build_outlined,
                    color: Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: compact ? constraints.maxWidth : 190,
                    child: DropdownButtonFormField<String>(
                      initialValue: _statusFilter,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Todos os status'),
                        ),
                        DropdownMenuItem(
                          value: 'available',
                          child: Text('Disponíveis'),
                        ),
                        DropdownMenuItem(
                          value: 'reserved',
                          child: Text('Reservados'),
                        ),
                        DropdownMenuItem(
                          value: 'maintenance',
                          child: Text('Manutenção'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _statusFilter = value ?? 'all'),
                    ),
                  ),
                  SizedBox(
                    width: compact ? constraints.maxWidth : 190,
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoryFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('Todas as categorias'),
                        ),
                        for (final group in data.groups)
                          DropdownMenuItem(
                            value: group['id'] as String,
                            child: Text(
                              group['name'] as String? ?? 'Categoria',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _categoryFilter = value ?? 'all'),
                    ),
                  ),
                  SizedBox(
                    width: compact ? constraints.maxWidth : 260,
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _search = value.trim()),
                      decoration: const InputDecoration(
                        labelText: 'Buscar veículo',
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Placa, modelo ou código',
                      ),
                    ),
                  ),
                  if (!widget.operatorMode)
                    OutlinedButton.icon(
                      onPressed: () => _manageGroups(data.groups),
                      icon: const Icon(Icons.block_outlined),
                      label: const Text('Bloquear categoria'),
                    ),
                  if (!widget.operatorMode)
                    FilledButton.icon(
                      onPressed: _createVehicle,
                      icon: const Icon(Icons.add),
                      label: const Text('Cadastrar veículo'),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _sectionHeader(
                context,
                'Mapa de disponibilidade da frota',
                'Visão por veículo e status em tempo real.',
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Exibir por: '),
                  IconButton(
                    onPressed: () => setState(() => _gridView = true),
                    icon: Icon(
                      Icons.grid_view,
                      color: _gridView
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _gridView = false),
                    icon: Icon(
                      Icons.view_list,
                      color: !_gridView
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                ],
              ),
              _gridView ? _vehicleGrid(vehicles) : _vehicleList(vehicles),
              const SizedBox(height: 28),
              _sectionHeader(
                context,
                'Reservas',
                'Acompanhe as reservas por status de pagamento.',
              ),
              const SizedBox(height: 12),
              if (compact)
                Column(
                  children: [
                    _reservationPanel(
                      context,
                      'Confirmadas e pagas',
                      paid,
                      Colors.green,
                    ),
                    const SizedBox(height: 16),
                    _reservationPanel(
                      context,
                      'Aguardando pagamento',
                      pending,
                      Colors.orange,
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _reservationPanel(
                        context,
                        'Confirmadas e pagas',
                        paid,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _reservationPanel(
                        context,
                        'Aguardando pagamento',
                        pending,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              if (!widget.operatorMode)
                OutlinedButton.icon(
                  onPressed: _createCompany,
                  icon: const Icon(Icons.add_business),
                  label: const Text('Adicionar serviço'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(BuildContext context, String title, String subtitle) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      );

  Widget _vehicleGrid(List<Map<String, dynamic>> vehicles) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1100
          ? 4
          : constraints.maxWidth >= 700
          ? 3
          : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: vehicles.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.15,
        ),
        itemBuilder: (_, index) => _VehicleTile(
          vehicle: vehicles[index],
          onEdit: widget.operatorMode
              ? null
              : () => _editVehicle(vehicles[index]),
        ),
      );
    },
  );

  Widget _vehicleList(List<Map<String, dynamic>> vehicles) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (final vehicle in vehicles)
          ListTile(
            leading: _VehicleThumb(vehicle: vehicle, size: 58),
            title: Text('${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'),
            subtitle: Text(
              '${vehicle['plate'] ?? 'Sem placa'} • ${vehicle['vehicle_type'] ?? 'car'}',
            ),
            trailing: _StatusChip(
              status: vehicle['status']?.toString() ?? 'available',
            ),
          ),
      ],
    ),
  );

  Widget _reservationPanel(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> reservations,
    Color color,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 12, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Chip(label: Text('${reservations.length}')),
            ],
          ),
          const Divider(),
          if (reservations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Nenhuma reserva neste status.'),
            ),
          for (final reservation in reservations.take(5))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('#${reservation['id'] ?? '—'}'),
              subtitle: Text(
                '${reservation['start_date'] ?? '—'} → ${reservation['end_date'] ?? '—'}',
              ),
              trailing: Text(
                'R\$ ${reservation['final_total'] ?? reservation['total_price'] ?? '—'}',
              ),
            ),
        ],
      ),
    ),
  );

  Future<void> _manageGroups(List<Map<String, dynamic>> groups) async {
    if (groups.isEmpty || _token == null) {
      _message('Cadastre uma categoria antes de bloquear a frota.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bloqueio de categorias'),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final group in groups)
                SwitchListTile(
                  title: Text(group['name'] as String? ?? 'Categoria'),
                  subtitle: Text(
                    (group['is_blocked'] == true)
                        ? 'Bloqueada para novas reservas'
                        : 'Disponível para reservas',
                  ),
                  value: group['is_blocked'] == true,
                  onChanged: (value) async {
                    try {
                      await _service.setGroupBlocked(
                        groupId: group['id'] as String,
                        token: _token!,
                        blocked: value,
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (mounted) setState(() => _future = _load());
                    } catch (error) {
                      _message(
                        'Não foi possível atualizar a categoria: $error',
                      );
                    }
                  },
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

  Future<_CompanyForm?> _showCompanyDialog() async {
    final name = TextEditingController();
    final address = TextEditingController();
    final cnpj = TextEditingController();
    String? logoName;
    List<int>? logoBytes;
    return showDialog<_CompanyForm>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo serviço de locação'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Endereço'),
              ),
              TextField(
                controller: cnpj,
                decoration: const InputDecoration(labelText: 'CNPJ (opcional)'),
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setLogoState) => OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await FilePicker.platform.pickFiles(
                      type: FileType.image,
                      withData: true,
                    );
                    if (picked != null && picked.files.single.bytes != null) {
                      setLogoState(() {
                        logoName = picked.files.single.name;
                        logoBytes = picked.files.single.bytes;
                      });
                    }
                  },
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    logoName == null
                        ? 'Adicionar logo da empresa'
                        : 'Logo: $logoName',
                  ),
                ),
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
              if (name.text.trim().length >= 2)
                Navigator.pop(
                  context,
                  _CompanyForm(
                    name.text,
                    address.text,
                    cnpj.text,
                    logoName,
                    logoBytes,
                  ),
                );
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<_VehicleForm?> _showVehicleDialog(
    List<Map<String, dynamic>> groups, {
    Map<String, dynamic>? vehicle,
  }) async {
    final brand = TextEditingController(text: vehicle?['brand']?.toString());
    final model = TextEditingController(text: vehicle?['model']?.toString());
    final year = TextEditingController(
      text: (vehicle?['manufacture_year'] ?? vehicle?['year'])?.toString(),
    );
    final crlvCode = TextEditingController(
      text: vehicle?['crlv_code']?.toString(),
    );
    final renavam = TextEditingController(
      text: vehicle?['renavam']?.toString(),
    );
    final chassis = TextEditingController(
      text: vehicle?['chassis']?.toString(),
    );
    String? crlvFileName;
    List<int>? crlvBytes;
    String? ownPhotoName;
    List<int>? ownPhotoBytes;
    final price = TextEditingController(
      text: vehicle?['price_per_day']?.toString(),
    );
    final plate = TextEditingController(text: vehicle?['plate']?.toString());
    var type = vehicle?['vehicle_type']?.toString() ?? 'car';
    String? groupId =
        vehicle?['group_id']?.toString() ??
        groups.firstOrNull?['id'] as String?;
    var groupCode =
        vehicle?['specifications']?['group_code']?.toString() ??
        groups.firstOrNull?['code']?.toString() ??
        'A';
    var category =
        vehicle?['specifications']?['category']?.toString() ?? 'hatch';
    List<Map<String, dynamic>> suggestions = const [];
    List<String> photoUrls = const [];
    Map<String, dynamic> specifications = const {};
    var searching = false;
    var step = 0;
    final currentYear = DateTime.now().year;
    final brandOptions = <String>{
      'Fiat',
      'Volkswagen',
      'Chevrolet',
      'Toyota',
      'Hyundai',
      'Honda',
      'Renault',
      'Nissan',
      'Yamaha',
      'BMW',
      'Outra',
      if (brand.text.trim().isNotEmpty) brand.text.trim(),
    }.toList();
    return showDialog<_VehicleForm>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> searchCatalog() async {
            final parsedYear = int.tryParse(year.text);
            if (brand.text.trim().isEmpty || parsedYear == null) return;
            setDialogState(() => searching = true);
            try {
              final found = await _service.catalogModels(
                make: brand.text,
                year: parsedYear,
                vehicleType: type,
                token: _token!,
              );
              setDialogState(() {
                suggestions = found;
                searching = false;
              });
            } catch (_) {
              setDialogState(() {
                suggestions = [];
                searching = false;
              });
            }
          }

          void finish() {
            final parsed = double.tryParse(price.text.replaceAll(',', '.'));
            if (brand.text.trim().isEmpty ||
                model.text.trim().isEmpty ||
                parsed == null ||
                parsed <= 0) {
              return;
            }
            Navigator.of(dialogContext).pop(
              _VehicleForm(
                type,
                brand.text,
                model.text,
                parsed,
                int.tryParse(year.text),
                groupId,
                photoUrls.where((item) => item.isNotEmpty).toList(),
                {
                  ...specifications,
                  'group_code': groupCode,
                  'category': category,
                },
                int.tryParse(year.text),
                crlvCode.text,
                renavam.text,
                chassis.text,
                plate.text,
                crlvFileName,
                crlvBytes,
                ownPhotoName,
                ownPhotoBytes,
              ),
            );
          }

          final steps = [
            Step(
              title: const Text('Grupo e tipo'),
              isActive: step >= 0,
              content: Column(
                children: [
                  if (groups.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: groupId,
                      decoration: const InputDecoration(
                        labelText: 'Grupo do veículo',
                      ),
                      items: [
                        for (final group in groups)
                          DropdownMenuItem(
                            value: group['id'] as String,
                            child: SizedBox(
                              width: 360,
                              child: Text(
                                group['name'] as String? ?? 'Grupo',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        final selected = groups.firstWhere(
                          (group) => group['id'] == value,
                        );
                        setDialogState(() {
                          groupId = value;
                          groupCode = selected['code']?.toString() ?? groupCode;
                          type = selected['vehicle_type'] as String? ?? 'car';
                          if (price.text.isEmpty &&
                              selected['suggested_price_per_day'] != null) {
                            price.text =
                                '${selected['suggested_price_per_day']}';
                          }
                        });
                      },
                    ),
                  if (groups.isEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: groupCode,
                      decoration: const InputDecoration(
                        labelText: 'Grupo do veículo',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'A', child: Text('Grupo A')),
                        DropdownMenuItem(value: 'B', child: Text('Grupo B')),
                        DropdownMenuItem(value: 'C', child: Text('Grupo C')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => groupCode = value ?? groupCode),
                    ),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de veículo',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'car', child: Text('Carro')),
                      DropdownMenuItem(
                        value: 'motorcycle',
                        child: Text('Motocicleta'),
                      ),
                      DropdownMenuItem(
                        value: 'bicycle',
                        child: Text('Bicicleta'),
                      ),
                      DropdownMenuItem(
                        value: 'quadricycle',
                        child: Text('Quadriciclo'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => type = value ?? 'car'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: const [
                      DropdownMenuItem(value: 'hatch', child: Text('Hatch')),
                      DropdownMenuItem(value: 'sedan', child: Text('Sedan')),
                      DropdownMenuItem(value: 'suv', child: Text('SUV')),
                      DropdownMenuItem(value: 'pickup', child: Text('Picape')),
                      DropdownMenuItem(value: 'truck', child: Text('Caminhão')),
                      DropdownMenuItem(value: 'van', child: Text('Van')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => category = value ?? 'hatch'),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Modelo'),
              isActive: step >= 1,
              content: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: brandOptions.contains(brand.text)
                        ? brand.text
                        : 'Outra',
                    decoration: const InputDecoration(labelText: 'Marca'),
                    items: [
                      for (final option in brandOptions)
                        DropdownMenuItem(value: option, child: Text(option)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        brand.text = value == 'Outra' ? '' : value;
                        suggestions = const [];
                        model.clear();
                      });
                    },
                  ),
                  if (suggestions.isEmpty)
                    TextField(
                      controller: model,
                      decoration: const InputDecoration(
                        labelText: 'Modelo (busque para selecionar)',
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue:
                          suggestions.any((item) => item['model'] == model.text)
                          ? model.text
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Modelo encontrado',
                      ),
                      items: [
                        for (final item in suggestions)
                          DropdownMenuItem(
                            value: item['model']?.toString(),
                            child: Text(
                              item['model']?.toString() ?? 'Modelo',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        final selected = suggestions.firstWhere(
                          (item) => item['model']?.toString() == value,
                        );
                        setDialogState(() {
                          model.text = value ?? '';
                          photoUrls = [
                            for (final url
                                in (selected['photo_urls'] as List<dynamic>? ??
                                    const []))
                              url.toString(),
                          ];
                          specifications =
                              (selected['specifications']
                                  as Map<String, dynamic>?) ??
                              const {};
                        });
                      },
                    ),
                  TextField(
                    controller: plate,
                    decoration: const InputDecoration(labelText: 'Placa'),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: int.tryParse(year.text),
                    decoration: const InputDecoration(
                      labelText: 'Ano do modelo',
                    ),
                    items: [
                      for (var value = currentYear + 1; value >= 1980; value--)
                        DropdownMenuItem(value: value, child: Text('$value')),
                    ],
                    onChanged: (value) => setDialogState(
                      () => year.text = value?.toString() ?? '',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: searchCatalog,
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar modelo e especificações'),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          withData: true,
                        );
                        if (picked != null &&
                            picked.files.single.bytes != null) {
                          setDialogState(() {
                            ownPhotoName = picked.files.single.name;
                            ownPhotoBytes = picked.files.single.bytes;
                            photoUrls = [...photoUrls, ''];
                          });
                        }
                      },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        ownPhotoName == null
                            ? 'Adicionar foto do veículo'
                            : 'Foto adicionada: $ownPhotoName',
                      ),
                    ),
                  ),
                  if (searching)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: LinearProgressIndicator(),
                    ),
                  if (!searching && suggestions.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Nenhum modelo encontrado ainda.'),
                    ),
                  if (photoUrls.isNotEmpty)
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photoUrls.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, index) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            photoUrls[index],
                            width: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Step(
              title: const Text('Documentos e preço'),
              isActive: step >= 2,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: crlvCode,
                    decoration: const InputDecoration(
                      labelText: 'Código do CRLV',
                    ),
                  ),
                  TextField(
                    controller: renavam,
                    decoration: const InputDecoration(labelText: 'RENAVAM'),
                  ),
                  TextField(
                    controller: chassis,
                    decoration: const InputDecoration(labelText: 'Chassi'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                        withData: true,
                      );
                      if (picked != null && picked.files.single.bytes != null)
                        setDialogState(() {
                          crlvFileName = picked.files.single.name;
                          crlvBytes = picked.files.single.bytes;
                        });
                    },
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      crlvFileName == null
                          ? 'Anexar CRLV (PDF ou imagem)'
                          : 'CRLV: $crlvFileName',
                    ),
                  ),
                  TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Diária (R\$)',
                    ),
                  ),
                  if (photoUrls.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '${photoUrls.length} foto(s) sugerida(s) encontrada(s). Você poderá substituir por fotos próprias após o cadastro.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text('Tipo: $type'),
                  Text('Modelo: ${brand.text} ${model.text}'),
                ],
              ),
            ),
          ];

          return AlertDialog(
            title: const Text('Novo veículo da frota'),
            content: SizedBox(
              width: 560,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 560),
                child: SingleChildScrollView(
                  child: Stepper(
                    currentStep: step,
                    physics: const ClampingScrollPhysics(),
                    onStepTapped: (value) => setDialogState(() => step = value),
                    onStepContinue: () {
                      if (step < steps.length - 1) {
                        setDialogState(() => step += 1);
                      } else {
                        finish();
                      }
                    },
                    onStepCancel: () {
                      if (step > 0) {
                        setDialogState(() => step -= 1);
                      } else {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    controlsBuilder: (context, details) => Row(
                      children: [
                        FilledButton(
                          onPressed: details.onStepContinue,
                          child: Text(
                            step == steps.length - 1
                                ? 'Salvar veículo'
                                : 'Avançar',
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: Text(step == 0 ? 'Cancelar' : 'Voltar'),
                        ),
                      ],
                    ),
                    steps: steps,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RentalDashboardData {
  final List<Map<String, dynamic>> companies;
  final List<Map<String, dynamic>> vehicles;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> reservations;
  const _RentalDashboardData({
    required this.companies,
    this.vehicles = const [],
    this.groups = const [],
    this.reservations = const [],
  });
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .12),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _VehicleTile extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final VoidCallback? onEdit;
  const _VehicleTile({required this.vehicle, this.onEdit});
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _VehicleThumb(vehicle: vehicle),
              Positioned(
                top: 8,
                right: 8,
                child: _StatusChip(
                  status: vehicle['status']?.toString() ?? 'available',
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${vehicle['plate'] ?? 'Sem placa'} • ${vehicle['vehicle_type'] ?? 'car'}',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'Editar veículo',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VehicleThumb extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final double? size;
  const _VehicleThumb({required this.vehicle, this.size});
  @override
  Widget build(BuildContext context) {
    final photos = (vehicle['photo_urls'] as List<dynamic>?) ?? const [];
    final url = photos.isNotEmpty ? photos.first.toString() : '';
    final fallback = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.directions_car_outlined, size: size == null ? 42 : 28),
    );
    if (url.isEmpty)
      return SizedBox(width: size, height: size, child: fallback);
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final (label, color) = switch (normalized) {
      'reserved' => ('Em locação', Colors.indigo),
      'maintenance' => ('Manutenção', Colors.orange),
      'blocked' => ('Bloqueado', Colors.red),
      _ => ('Disponível', Colors.green),
    };
    return Chip(
      label: Text(label, style: TextStyle(color: color, fontSize: 11)),
      backgroundColor: color.withValues(alpha: .12),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _CompanyForm {
  final String name, address, cnpj;
  final String? logoName;
  final List<int>? logoBytes;
  const _CompanyForm(
    this.name,
    this.address,
    this.cnpj,
    this.logoName,
    this.logoBytes,
  );
}

class _VehicleForm {
  final String type, brand, model;
  final double price;
  final int? year;
  final String? groupId;
  final List<String> photoUrls;
  final Map<String, dynamic> specifications;
  final int? manufactureYear;
  final String crlvCode;
  final String renavam;
  final String chassis;
  final String plate;
  final String? crlvFileName;
  final List<int>? crlvBytes;
  final String? ownPhotoName;
  final List<int>? ownPhotoBytes;
  const _VehicleForm(
    this.type,
    this.brand,
    this.model,
    this.price,
    this.year,
    this.groupId,
    this.photoUrls,
    this.specifications,
    this.manufactureYear,
    this.crlvCode,
    this.renavam,
    this.chassis,
    this.plate,
    this.crlvFileName,
    this.crlvBytes,
    this.ownPhotoName,
    this.ownPhotoBytes,
  );
}
