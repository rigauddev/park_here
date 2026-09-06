import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/managed_parking_model.dart';
import '../providers/partner_parking_provider.dart';

class ParkingManagementPage extends ConsumerWidget {
  const ParkingManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parkings = ref.watch(partnerParkingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão do estacionamento'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () => ref.invalidate(partnerParkingProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
      body: parkings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhum estacionamento cadastrado.'),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _ManagedParkingCard(
                parking: items[index],
                onEdit: () => _openForm(context, items[index]),
              );
            },
          );
        },
      ),
    );
  }

  void _openForm(BuildContext context, [ManagedParkingModel? parking]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParkingManagementFormPage(parking: parking),
      ),
    );
  }
}

class _ManagedParkingCard extends StatelessWidget {
  final ManagedParkingModel parking;
  final VoidCallback onEdit;

  const _ManagedParkingCard({required this.parking, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final activeServices = parking.services.where(
      (service) => service.isActive,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.softCyan,
                  foregroundColor: AppTheme.primary,
                  child: const Icon(Icons.local_parking),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parking.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        parking.address,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  '${parking.availableSpots}/${parking.totalSpots} vagas',
                ),
                _InfoChip('${parking.coveredSpots} cobertas'),
                _InfoChip('${parking.uncoveredSpots} descobertas'),
                if (parking.vipSpots > 0) _InfoChip('${parking.vipSpots} VIP'),
                if (parking.largeSpots > 0)
                  _InfoChip('${parking.largeSpots} carro grande'),
                if (parking.busSpots > 0)
                  _InfoChip('${parking.busSpots} ônibus'),
                if (parking.pickupSpots > 0)
                  _InfoChip('${parking.pickupSpots} picape'),
                _InfoChip(parking.isActive ? 'Ativo' : 'Inativo'),
              ],
            ),
            const SizedBox(height: 14),
            _PriceLine(label: 'Descoberta', pricing: parking.uncoveredPricing),
            if (parking.coveredSpots > 0)
              _PriceLine(label: 'Coberta', pricing: parking.coveredPricing),
            if (activeServices.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Serviços: ${activeServices.map((s) => '${s.name} R\$ ${s.price.toStringAsFixed(2)}').join(' | ')}',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: AppTheme.softCyan,
      side: BorderSide.none,
      labelStyle: const TextStyle(
        color: AppTheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final String label;
  final ParkingAreaPricingModel pricing;

  const _PriceLine({required this.label, required this.pricing});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: R\$ ${pricing.firstHourPrice.toStringAsFixed(2)} primeira hora, '
      'R\$ ${pricing.dailyPrice.toStringAsFixed(2)} diária, '
      'R\$ ${pricing.weeklyPrice.toStringAsFixed(2)} semanal',
      style: const TextStyle(color: AppTheme.primary),
    );
  }
}

class ParkingManagementFormPage extends ConsumerStatefulWidget {
  final ManagedParkingModel? parking;

  const ParkingManagementFormPage({super.key, this.parking});

  @override
  ConsumerState<ParkingManagementFormPage> createState() =>
      _ParkingManagementFormPageState();
}

class _ParkingManagementFormPageState
    extends ConsumerState<ParkingManagementFormPage> {
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final latController = TextEditingController();
  final lngController = TextEditingController();
  final totalController = TextEditingController();
  final availableController = TextEditingController();
  final coveredController = TextEditingController();
  final uncoveredController = TextEditingController();
  final vipController = TextEditingController();
  final largeController = TextEditingController();
  final busController = TextEditingController();
  final pickupController = TextEditingController();

  final uncoveredFirstController = TextEditingController();
  final uncoveredAdditionalController = TextEditingController();
  final uncoveredDailyController = TextEditingController();
  final uncoveredWeeklyController = TextEditingController();
  final uncoveredMonthlyController = TextEditingController();

  final coveredFirstController = TextEditingController();
  final coveredAdditionalController = TextEditingController();
  final coveredDailyController = TextEditingController();
  final coveredWeeklyController = TextEditingController();
  final coveredMonthlyController = TextEditingController();

  final serviceNameController = TextEditingController();
  final servicePriceController = TextEditingController();

  bool has24hGate = false;
  bool hasSecuritySystem = false;
  bool wantsAutomaticAccess = false;
  bool hasAutomaticAccess = false;
  bool isActive = true;
  String serviceCode = 'car_wash';
  List<ManagedParkingServiceModel> services = [];
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final parking = widget.parking;
    if (parking == null) {
      cityController.text = 'Valenca';
      latController.text = '-13.3703';
      lngController.text = '-39.0731';
      coveredController.text = '0';
      uncoveredController.text = '0';
      availableController.text = '0';
      vipController.text = '0';
      largeController.text = '0';
      busController.text = '0';
      pickupController.text = '0';
      return;
    }

    nameController.text = parking.name;
    addressController.text = parking.address;
    cityController.text = parking.city;
    latController.text = parking.lat.toString();
    lngController.text = parking.lng.toString();
    totalController.text = parking.totalSpots.toString();
    availableController.text = parking.availableSpots.toString();
    coveredController.text = parking.coveredSpots.toString();
    uncoveredController.text = parking.uncoveredSpots.toString();
    vipController.text = parking.vipSpots.toString();
    largeController.text = parking.largeSpots.toString();
    busController.text = parking.busSpots.toString();
    pickupController.text = parking.pickupSpots.toString();
    has24hGate = parking.has24hGate;
    hasSecuritySystem = parking.hasSecuritySystem;
    wantsAutomaticAccess = parking.wantsAutomaticAccess;
    hasAutomaticAccess = parking.hasAutomaticAccess;
    isActive = parking.isActive;
    services = [...parking.services];
    _fillPricing(parking.uncoveredPricing, [
      uncoveredFirstController,
      uncoveredAdditionalController,
      uncoveredDailyController,
      uncoveredWeeklyController,
      uncoveredMonthlyController,
    ]);
    _fillPricing(parking.coveredPricing, [
      coveredFirstController,
      coveredAdditionalController,
      coveredDailyController,
      coveredWeeklyController,
      coveredMonthlyController,
    ]);
  }

  @override
  void dispose() {
    for (final controller in [
      nameController,
      addressController,
      cityController,
      latController,
      lngController,
      totalController,
      availableController,
      coveredController,
      uncoveredController,
      vipController,
      largeController,
      busController,
      pickupController,
      uncoveredFirstController,
      uncoveredAdditionalController,
      uncoveredDailyController,
      uncoveredWeeklyController,
      uncoveredMonthlyController,
      coveredFirstController,
      coveredAdditionalController,
      coveredDailyController,
      coveredWeeklyController,
      coveredMonthlyController,
      serviceNameController,
      servicePriceController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.parking == null
              ? 'Novo estacionamento'
              : 'Editar estacionamento',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: 'Estabelecimento',
            children: [
              _field(nameController, 'Nome'),
              _field(addressController, 'Endereço'),
              _field(cityController, 'Cidade'),
              Row(
                children: [
                  Expanded(child: _field(latController, 'Latitude')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(lngController, 'Longitude')),
                ],
              ),
              SwitchListTile(
                value: isActive,
                onChanged: (value) => setState(() => isActive = value),
                title: const Text('Ativo no app'),
                subtitle: const Text(
                  'Quando ativo, o estacionamento aparece para reservas depois da aprovacao.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          _Section(
            title: 'Vagas',
            children: [
              Row(
                children: [
                  Expanded(child: _field(totalController, 'Total')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(availableController, 'Disponíveis')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field(coveredController, 'Cobertas')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(uncoveredController, 'Descobertas')),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tipos especiais de vaga',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field(vipController, 'VIP')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(largeController, 'Carro grande')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field(busController, 'Ônibus')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(pickupController, 'Picape')),
                ],
              ),
              SwitchListTile(
                value: has24hGate,
                onChanged: (value) => setState(() => has24hGate = value),
                title: const Text('Portaria 24h'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: hasSecuritySystem,
                onChanged: (value) => setState(() => hasSecuritySystem = value),
                title: const Text('Sistema de segurança'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: wantsAutomaticAccess,
                onChanged: (value) =>
                    setState(() => wantsAutomaticAccess = value),
                title: const Text('Interesse em atendimento automático'),
                subtitle: const Text(
                  'Reconhecimento facial e portão automático ficam para V2.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: hasAutomaticAccess,
                onChanged: (value) =>
                    setState(() => hasAutomaticAccess = value),
                title: const Text('Já possui atendimento automático'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          _PricingSection(
            title: 'Taxas área descoberta',
            controllers: [
              uncoveredFirstController,
              uncoveredAdditionalController,
              uncoveredDailyController,
              uncoveredWeeklyController,
              uncoveredMonthlyController,
            ],
          ),
          _PricingSection(
            title: 'Taxas área coberta',
            controllers: [
              coveredFirstController,
              coveredAdditionalController,
              coveredDailyController,
              coveredWeeklyController,
              coveredMonthlyController,
            ],
          ),
          _Section(
            title: 'Serviços extras',
            children: [
              for (final service in services)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    service.code == 'car_wash'
                        ? Icons.local_car_wash
                        : Icons.add_business_outlined,
                  ),
                  title: Text(service.name),
                  subtitle: Text('R\$ ${service.price.toStringAsFixed(2)}'),
                  trailing: IconButton(
                    tooltip: 'Remover',
                    onPressed: () => setState(() => services.remove(service)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: serviceCode,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: const [
                        DropdownMenuItem(
                          value: 'car_wash',
                          child: Text('Lava jato'),
                        ),
                        DropdownMenuItem(
                          value: 'insurance',
                          child: Text('Seguro'),
                        ),
                        DropdownMenuItem(
                          value: 'transport',
                          child: Text('Transporte'),
                        ),
                        DropdownMenuItem(
                          value: 'vip_spot',
                          child: Text('Vaga VIP'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => serviceCode = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _field(servicePriceController, 'Preço')),
                ],
              ),
              _field(serviceNameController, 'Nome do serviço'),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _addService,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar serviço'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: isSaving ? null : _save,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Salvar gestão'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType:
            label == 'Nome' ||
                label == 'Endereço' ||
                label == 'Cidade' ||
                label == 'Nome do serviço'
            ? TextInputType.text
            : const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  void _addService() {
    final name = serviceNameController.text.trim();
    final price = double.tryParse(
      servicePriceController.text.replaceAll(',', '.'),
    );

    if (name.isEmpty || price == null || !price.isFinite || price < 0) {
      _showMessage('Informe nome e preço válido, maior ou igual a zero.');
      return;
    }

    if (services.any((service) => service.code == serviceCode)) {
      _showMessage('Este tipo de serviço já foi adicionado.');
      return;
    }

    setState(() {
      services = [
        ...services,
        ManagedParkingServiceModel(
          code: serviceCode,
          name: name,
          price: price,
          isActive: true,
        ),
      ];
      serviceNameController.clear();
      servicePriceController.clear();
    });
  }

  Future<void> _save() async {
    try {
      final parking = _buildParking();
      setState(() => isSaving = true);
      await ref.read(partnerParkingProvider.notifier).save(parking);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Estacionamento salvo.')));
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  ManagedParkingModel _buildParking() {
    final total = _int(totalController, 'Total');
    final covered = _int(coveredController, 'Cobertas');
    final uncovered = _int(uncoveredController, 'Descobertas');
    final available = _int(availableController, 'Disponíveis');
    final vip = _int(vipController, 'VIP');
    final large = _int(largeController, 'Carro grande');
    final bus = _int(busController, 'Ônibus');
    final pickup = _int(pickupController, 'Picape');

    if (total <= 0 || available > total) {
      throw Exception('Informe total positivo e disponibilidade até o total.');
    }

    if (covered + uncovered != total) {
      throw Exception('Cobertas + descobertas deve ser igual ao total.');
    }

    if (vip + large + bus + pickup > total) {
      throw Exception('Tipos especiais não podem passar o total de vagas.');
    }

    return ManagedParkingModel(
      id: widget.parking?.id,
      name: _required(nameController, 'Nome'),
      address: _required(addressController, 'Endereço'),
      city: _required(cityController, 'Cidade'),
      lat: _double(latController, 'Latitude'),
      lng: _double(lngController, 'Longitude'),
      totalSpots: total,
      availableSpots: available,
      coveredSpots: covered,
      uncoveredSpots: uncovered,
      vipSpots: vip,
      largeSpots: large,
      busSpots: bus,
      pickupSpots: pickup,
      hasVipSpots: vip > 0,
      has24hGate: has24hGate,
      hasSecuritySystem: hasSecuritySystem,
      wantsAutomaticAccess: wantsAutomaticAccess,
      hasAutomaticAccess: hasAutomaticAccess,
      isActive: isActive,
      uncoveredPricing: _pricing([
        uncoveredFirstController,
        uncoveredAdditionalController,
        uncoveredDailyController,
        uncoveredWeeklyController,
        uncoveredMonthlyController,
      ]),
      coveredPricing: _pricing([
        coveredFirstController,
        coveredAdditionalController,
        coveredDailyController,
        coveredWeeklyController,
        coveredMonthlyController,
      ]),
      services: services,
    );
  }

  ParkingAreaPricingModel _pricing(List<TextEditingController> controllers) {
    if (controllers.any((controller) => _double(controller, 'Tarifa') < 0)) {
      throw Exception('Tarifas não podem ser negativas.');
    }
    return ParkingAreaPricingModel(
      firstHourPrice: _double(controllers[0], 'Primeira hora'),
      additionalHourPrice: _double(controllers[1], 'Hora adicional'),
      dailyPrice: _double(controllers[2], 'Diária'),
      weeklyPrice: _double(controllers[3], 'Semanal'),
      monthlyPrice: _double(controllers[4], 'Mensal'),
    );
  }

  void _fillPricing(
    ParkingAreaPricingModel pricing,
    List<TextEditingController> controllers,
  ) {
    controllers[0].text = pricing.firstHourPrice.toString();
    controllers[1].text = pricing.additionalHourPrice.toString();
    controllers[2].text = pricing.dailyPrice.toString();
    controllers[3].text = pricing.weeklyPrice.toString();
    controllers[4].text = pricing.monthlyPrice.toString();
  }

  String _required(TextEditingController controller, String label) {
    final value = controller.text.trim();
    if (value.isEmpty) throw Exception('Informe $label.');
    return value;
  }

  int _int(TextEditingController controller, String label) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value < 0) {
      throw Exception('Informe $label corretamente.');
    }
    return value;
  }

  double _double(TextEditingController controller, String label) {
    final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite) {
      throw Exception('Informe $label corretamente.');
    }
    return value;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PricingSection extends StatelessWidget {
  final String title;
  final List<TextEditingController> controllers;

  const _PricingSection({required this.title, required this.controllers});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      children: [
        Row(
          children: [
            Expanded(child: _moneyField(controllers[0], 'Primeira hora')),
            const SizedBox(width: 10),
            Expanded(child: _moneyField(controllers[1], 'Hora adicional')),
          ],
        ),
        Row(
          children: [
            Expanded(child: _moneyField(controllers[2], 'Diária')),
            const SizedBox(width: 10),
            Expanded(child: _moneyField(controllers[3], 'Semanal')),
          ],
        ),
        _moneyField(controllers[4], 'Mensal'),
      ],
    );
  }

  Widget _moneyField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixText: 'R\$ '),
      ),
    );
  }
}
