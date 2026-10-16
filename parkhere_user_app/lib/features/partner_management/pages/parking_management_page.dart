import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/widgets/api_feedback.dart';
import '../models/managed_parking_model.dart';
import '../providers/partner_parking_provider.dart';
import '../models/partner_profile_model.dart';
import '../providers/partner_profile_provider.dart';
import 'partner_feature_access_page.dart';
import 'parking_convenience_page.dart';

class CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.substring(0, digits.length.clamp(0, 8));
    final formatted = limited.length > 5
        ? '${limited.substring(0, 5)}-${limited.substring(5)}'
        : limited;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ParkingManagementPage extends ConsumerWidget {
  const ParkingManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parkings = ref.watch(partnerParkingProvider);
    final partner = ref.watch(partnerProfileProvider).asData?.value;

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
        onPressed: () async {
          if (partner != null && partner.unitCount >= partner.unitLimit) {
            final unlocked = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => PartnerFeatureAccessPage(
                  partner: partner,
                  featureKey: 'additional_units',
                ),
              ),
            );
            if (unlocked == true) {
              ref.invalidate(partnerProfileProvider);
              ref.invalidate(partnerParkingProvider);
            }
            return;
          }
          _openForm(context, partner: partner);
        },
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
                onEdit: () =>
                    _openForm(context, parking: items[index], partner: partner),
                onConveniences: () =>
                    _openConveniences(context, partner, items[index]),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openConveniences(
    BuildContext context,
    PartnerProfileModel? partner,
    ManagedParkingModel parking,
  ) async {
    if (partner == null || parking.id == null) return;
    final feature = partner.featureDetails('convenience_management');
    if (feature?['is_enabled'] != true) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PartnerFeatureAccessPage(
            partner: partner,
            featureKey: 'convenience_management',
          ),
        ),
      );
      return;
    }
    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ParkingConveniencePage(
            parkingId: parking.id!,
            parkingName: parking.name,
          ),
        ),
      );
    }
  }

  void _openForm(
    BuildContext context, {
    ManagedParkingModel? parking,
    PartnerProfileModel? partner,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ParkingManagementFormPage(parking: parking, partner: partner),
      ),
    );
  }
}

class _OperatingHoursEditor extends StatelessWidget {
  final Map<String, Map<String, String>?> hours;
  final ValueChanged<Map<String, Map<String, String>?>> onChanged;
  const _OperatingHoursEditor({required this.hours, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {
      'mon': 'Segunda',
      'tue': 'Terça',
      'wed': 'Quarta',
      'thu': 'Quinta',
      'fri': 'Sexta',
      'sat': 'Sábado',
      'sun': 'Domingo',
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Horário de funcionamento',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Defina os dias e horários usados pela geração de escalas.',
            ),
            for (final entry in labels.entries)
              _dayRow(context, entry.key, entry.value),
          ],
        ),
      ),
    );
  }

  Widget _dayRow(BuildContext context, String key, String label) {
    final value = hours[key];
    final closed = value == null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      subtitle: Text(
        closed ? 'Fechado' : '${value['open']} – ${value['close']}',
      ),
      trailing: Switch(
        value: !closed,
        onChanged: (enabled) {
          final next = {...hours};
          next[key] = enabled ? {'open': '08:00', 'close': '18:00'} : null;
          onChanged(next);
        },
      ),
      onTap: closed
          ? null
          : () async {
              final initial = _parse(value['open'] ?? '08:00');
              final picked = await showTimePicker(
                context: context,
                initialTime: initial,
              );
              if (picked == null) return;
              if (!context.mounted) return;
              final finish = await showTimePicker(
                context: context,
                initialTime: _parse(value['close'] ?? '18:00'),
              );
              if (finish == null) return;
              if (!context.mounted) return;
              final next = {
                ...hours,
                key: {
                  'open': picked.format(context),
                  'close': finish.format(context),
                },
              };
              onChanged(next);
            },
    );
  }

  TimeOfDay _parse(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 8,
      minute: int.tryParse(parts.last) ?? 0,
    );
  }
}

class _ManagedParkingCard extends StatelessWidget {
  final ManagedParkingModel parking;
  final VoidCallback onEdit;
  final VoidCallback onConveniences;

  const _ManagedParkingCard({
    required this.parking,
    required this.onEdit,
    required this.onConveniences,
  });

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
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onConveniences,
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Conveniência'),
              ),
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
  final PartnerProfileModel? partner;

  const ParkingManagementFormPage({super.key, this.parking, this.partner});

  @override
  ConsumerState<ParkingManagementFormPage> createState() =>
      _ParkingManagementFormPageState();
}

class _ParkingManagementFormPageState
    extends ConsumerState<ParkingManagementFormPage> {
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final streetController = TextEditingController();
  final numberController = TextEditingController();
  final neighborhoodController = TextEditingController();
  final cepController = TextEditingController();
  final streetSearchController = TextEditingController();
  final cityController = TextEditingController();
  final latController = TextEditingController();
  final lngController = TextEditingController();
  final totalController = TextEditingController();
  final availableController = TextEditingController();
  final arrivalToleranceController = TextEditingController();
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
  final Map<String, List<TextEditingController>> specialPricing = {
    'vip': List.generate(5, (_) => TextEditingController()),
    'large': List.generate(5, (_) => TextEditingController()),
    'bus': List.generate(5, (_) => TextEditingController()),
    'pickup': List.generate(5, (_) => TextEditingController()),
  };

  final serviceDescriptionController = TextEditingController();

  bool has24hGate = false;
  String workRegime = 'commercial';
  bool hasSecuritySystem = false;
  bool wantsAutomaticAccess = false;
  bool hasAutomaticAccess = false;
  bool isActive = true;
  final Map<String, Map<String, String>?> operatingHours = {
    for (final day in const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'])
      day: {'open': '08:00', 'close': '18:00'},
  };
  String serviceCode = 'car_wash';
  List<ManagedParkingServiceModel> services = [];
  bool isSaving = false;
  bool isSearchingCep = false;
  String? cepMessage;
  String? invalidField;

  int _sumSpots() => [
    coveredController,
    uncoveredController,
    vipController,
    largeController,
    busController,
    pickupController,
  ].fold(0, (sum, controller) => sum + (int.tryParse(controller.text) ?? 0));

  void _refreshTotal() {
    final total = _sumSpots();
    if (totalController.text != total.toString()) {
      totalController.text = total.toString();
    }
    if (widget.parking == null &&
        availableController.text != total.toString()) {
      availableController.text = total.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    final parking = widget.parking;
    for (final controller in [
      coveredController,
      uncoveredController,
      vipController,
      largeController,
      busController,
      pickupController,
    ]) {
      controller.addListener(_refreshTotal);
    }
    if (parking == null) {
      cityController.text = 'Valenca';
      latController.text = '-13.3703';
      lngController.text = '-39.0731';
      coveredController.text = '0';
      uncoveredController.text = '0';
      availableController.text = '0';
      arrivalToleranceController.text = '15';
      vipController.text = '0';
      largeController.text = '0';
      busController.text = '0';
      pickupController.text = '0';
      return;
    }

    nameController.text = parking.name;
    addressController.text = parking.address;
    streetController.text = parking.street ?? '';
    numberController.text = parking.number ?? '';
    neighborhoodController.text = parking.neighborhood ?? '';
    cepController.text = parking.postalCode ?? '';
    cityController.text = parking.city;
    latController.text = parking.lat.toString();
    lngController.text = parking.lng.toString();
    totalController.text = parking.totalSpots.toString();
    availableController.text = parking.availableSpots.toString();
    arrivalToleranceController.text = parking.arrivalToleranceMinutes
        .toString();
    coveredController.text = parking.coveredSpots.toString();
    uncoveredController.text = parking.uncoveredSpots.toString();
    vipController.text = parking.vipSpots.toString();
    largeController.text = parking.largeSpots.toString();
    busController.text = parking.busSpots.toString();
    pickupController.text = parking.pickupSpots.toString();
    has24hGate = parking.has24hGate;
    workRegime = parking.workRegime;
    operatingHours
      ..clear()
      ..addAll(parking.operatingHours);
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
    for (final entry in parking.categoryPricing.entries) {
      if (specialPricing.containsKey(entry.key)) {
        _fillPricing(entry.value, specialPricing[entry.key]!);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      nameController,
      addressController,
      streetController,
      numberController,
      neighborhoodController,
      cepController,
      streetSearchController,
      cityController,
      latController,
      lngController,
      totalController,
      availableController,
      arrivalToleranceController,
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
      serviceDescriptionController,
      ...specialPricing.values.expand((items) => items),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: _field(
                      cepController,
                      'CEP',
                      keyboardType: TextInputType.number,
                      inputFormatters: [CepInputFormatter()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FilledButton.tonalIcon(
                      onPressed: isSearchingCep ? null : _searchCep,
                      icon: isSearchingCep
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: const Text('Buscar'),
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(
                      streetSearchController,
                      'Buscar por rua e número',
                      keyboardType: TextInputType.streetAddress,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FilledButton.tonalIcon(
                      onPressed: isSearchingCep ? null : _searchStreet,
                      icon: const Icon(Icons.location_searching),
                      label: const Text('Buscar rua'),
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _field(streetController, 'Nome da rua')),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 96,
                    child: _field(
                      numberController,
                      'Número',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              _field(neighborhoodController, 'Bairro'),
              _field(addressController, 'Endereço completo', readOnly: true),
              if (cepMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    cepMessage!,
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                ),
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
                  Expanded(
                    child: _field(totalController, 'Total', readOnly: true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      availableController,
                      'Disponíveis',
                      readOnly: true,
                    ),
                  ),
                ],
              ),
              _field(arrivalToleranceController, 'Tolerância de chegada (min)'),
              Row(
                children: [
                  Expanded(child: _field(coveredController, 'Cobertas')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(uncoveredController, 'Descobertas')),
                ],
              ),
              for (final entry in {
                'vip': 'VIP',
                'large': 'Carro grande',
                'bus': 'Ônibus',
                'pickup': 'Picape',
              }.entries)
                if (_countFor(entry.key) > 0)
                  _PricingSection(
                    title: 'Tarifas ${entry.value}',
                    controllers: specialPricing[entry.key]!,
                    invalidField: invalidField,
                  ),
              OutlinedButton.icon(
                onPressed: () => _showMessage(
                  'Para criar um tipo especial, informe quantidade acima de zero e suas tarifas.',
                ),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar tipo especial'),
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
              DropdownButtonFormField<String>(
                initialValue: workRegime,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.strings.isEnglish
                      ? 'Work-schedule regime'
                      : 'Jornada usada para gerar escalas',
                  helperText: context.strings.isEnglish
                      ? 'Gate access hours and employee shifts are separate settings.'
                      : 'O funcionamento da portaria e a jornada dos operadores são configurações diferentes.',
                ),
                items: [
                  DropdownMenuItem(
                    value: 'commercial',
                    child: Text(
                      context.strings.isEnglish
                          ? 'Commercial schedule'
                          : 'Horário comercial',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'three_shifts',
                    child: Text(
                      context.strings.isEnglish
                          ? '24h coverage · three 8h shifts'
                          : 'Cobertura 24h · três turnos de 8h',
                    ),
                  ),
                  DropdownMenuItem(
                    value: '24h_on_3off',
                    child: Text(
                      context.strings.isEnglish
                          ? '24h on · three days off'
                          : 'Plantão de 24h · três dias de folga',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'administrative_8h',
                    child: Text(
                      context.strings.isEnglish
                          ? 'Administrative · 8h per day'
                          : 'Administrativo · 8h por dia',
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => workRegime = value ?? 'commercial'),
              ),
              _OperatingHoursEditor(
                hours: operatingHours,
                onChanged: (value) => setState(
                  () => operatingHours
                    ..clear()
                    ..addAll(value),
                ),
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
            invalidField: invalidField,
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
            invalidField: invalidField,
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
                  title: Text(_serviceLabel(service.code)),
                  subtitle: Text(
                    service.description?.trim().isNotEmpty == true
                        ? service.description!
                        : 'Serviço extra disponível nesta unidade.',
                  ),
                  trailing: IconButton(
                    tooltip: 'Remover',
                    onPressed: () => setState(() => services.remove(service)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              DropdownButtonFormField<String>(
                initialValue: serviceCode,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'car_wash', child: Text('Lava jato')),
                  DropdownMenuItem(value: 'insurance', child: Text('Seguro')),
                  DropdownMenuItem(
                    value: 'transport',
                    child: Text('Transporte'),
                  ),
                  DropdownMenuItem(value: 'vip_spot', child: Text('Vaga VIP')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => serviceCode = value);
                },
              ),
              _field(
                serviceDescriptionController,
                'Descrição do serviço (opcional)',
                keyboardType: TextInputType.text,
              ),
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

  Future<void> _searchCep() async {
    final cep = cepController.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) {
      setState(() => cepMessage = 'Informe um CEP válido com 8 dígitos.');
      return;
    }
    setState(() {
      isSearchingCep = true;
      cepMessage = null;
    });
    try {
      final response = await http.get(
        Uri.parse('https://viacep.com.br/ws/$cep/json/'),
      );
      if (response.statusCode != 200) throw Exception('CEP não encontrado.');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['erro'] == true) throw Exception('CEP não encontrado.');
      final street = (data['logradouro'] as String? ?? '').trim();
      final neighborhood = (data['bairro'] as String? ?? '').trim();
      final city = (data['localidade'] as String? ?? '').trim();
      final state = (data['uf'] as String? ?? '').trim();
      final address = [
        street,
        neighborhood,
        city,
        state,
      ].where((part) => part.isNotEmpty).join(', ');
      if (!mounted) return;
      streetController.text = street;
      neighborhoodController.text = neighborhood;
      addressController.text = address;
      cityController.text = city;

      // ViaCEP does not provide coordinates. Nominatim fills them from the
      // selected address; the user can still edit the result before saving.
      final query = Uri.encodeQueryComponent('$address, Brasil');
      final geo = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
        ),
        headers: const {'User-Agent': 'ParkHere/1.0 address lookup'},
      );
      if (geo.statusCode == 200) {
        final rows = jsonDecode(geo.body) as List<dynamic>;
        if (rows.isNotEmpty && mounted) {
          final first = rows.first as Map<String, dynamic>;
          latController.text = '${first['lat']}';
          lngController.text = '${first['lon']}';
        }
      }
      if (mounted) {
        setState(
          () => cepMessage =
              'Endereço encontrado. Revise e salve para confirmar.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => cepMessage = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => isSearchingCep = false);
    }
  }

  Future<void> _searchStreet() async {
    final street = streetSearchController.text.trim();
    if (street.length < 3) {
      setState(() => cepMessage = 'Informe pelo menos o nome da rua.');
      return;
    }
    setState(() {
      isSearchingCep = true;
      cepMessage = null;
    });
    try {
      final query = Uri.encodeQueryComponent(
        '$street, ${cityController.text.trim()}, Brasil',
      );
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5',
        ),
        headers: const {'User-Agent': 'ParkHere/1.0 address lookup'},
      );
      if (response.statusCode != 200) throw Exception('Rua não encontrada.');
      final rows = jsonDecode(response.body) as List<dynamic>;
      if (rows.isEmpty) throw Exception('Rua não encontrada.');
      final first = rows.first as Map<String, dynamic>;
      final details = first['address'] as Map<String, dynamic>? ?? const {};
      if (!mounted) return;
      final displayName = first['display_name'] as String?;
      if (displayName != null && displayName.trim().isNotEmpty) {
        addressController.text = displayName;
      }
      final road = details['road'] as String?;
      if (road != null) streetController.text = road;
      final houseNumber = details['house_number'] as String?;
      if (houseNumber != null) numberController.text = houseNumber;
      final neighborhood =
          (details['neighbourhood'] ?? details['suburb']) as String?;
      if (neighborhood != null) neighborhoodController.text = neighborhood;
      final city =
          (details['city'] ?? details['town'] ?? details['municipality'])
              as String?;
      if (city != null && city.isNotEmpty) cityController.text = city;
      latController.text = '${first['lat']}';
      lngController.text = '${first['lon']}';
      setState(
        () =>
            cepMessage = 'Endereço encontrado. Revise e salve para confirmar.',
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => cepMessage = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => isSearchingCep = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType:
            keyboardType ??
            (label == 'Nome' ||
                    label == 'Endereço' ||
                    label == 'Cidade' ||
                    label == 'Nome do serviço'
                ? TextInputType.text
                : const TextInputType.numberWithOptions(decimal: true)),
        readOnly: readOnly,
        inputFormatters: inputFormatters,
        // Keep the invalid control visible after an API/form validation error.
        decoration: InputDecoration(
          labelText: label,
          errorText: invalidField == label ? 'Corrija este campo' : null,
        ),
      ),
    );
  }

  void _addService() {
    if (services.any((service) => service.code == serviceCode)) {
      _showMessage('Este tipo de serviço já foi adicionado.');
      return;
    }

    final partner = widget.partner;
    if (partner != null && !partner.hasFeature('services_management')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PartnerFeatureAccessPage(
            partner: partner,
            featureKey: 'services_management',
          ),
        ),
      );
      return;
    }
    final currentUnitServices = widget.parking?.services.length ?? 0;
    final nextTenantCount =
        (partner?.serviceCount ?? 0) -
        currentUnitServices +
        services.length +
        1;
    if (partner != null && nextTenantCount > partner.serviceLimit) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PartnerFeatureAccessPage(
            partner: partner,
            featureKey: 'additional_services',
            requestedQuantity: nextTenantCount - partner.serviceLimit,
          ),
        ),
      );
      return;
    }

    setState(() {
      services = [
        ...services,
        ManagedParkingServiceModel(
          code: serviceCode,
          name: _serviceLabel(serviceCode),
          description: serviceDescriptionController.text.trim().isEmpty
              ? null
              : serviceDescriptionController.text.trim(),
          // The extra service itself is not charged. The platform fee for
          // adding extra services is managed centrally by the admin panel.
          price: 0,
          isActive: true,
        ),
      ];
      serviceDescriptionController.clear();
    });
  }

  String _serviceLabel(String code) => switch (code) {
    'car_wash' => 'Lava jato',
    'insurance' => 'Seguro',
    'transport' => 'Transporte',
    'vip_spot' => 'Vaga VIP',
    _ => code,
  };

  Future<void> _save() async {
    try {
      setState(() => invalidField = null);
      final parking = _buildParking();
      setState(() => isSaving = true);
      await ref.read(partnerParkingProvider.notifier).save(parking);
      if (!mounted) return;
      await ApiFeedback.show(context, 'Estacionamento salvo.', isError: false);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      if (error is _FieldValidationException) {
        setState(() => invalidField = error.field);
      } else {
        final message = error.toString().toLowerCase();
        final field = message.contains('diária') || message.contains('daily')
            ? 'Diária'
            : message.contains('semanal') || message.contains('weekly')
            ? 'Semanal'
            : message.contains('mensal') || message.contains('monthly')
            ? 'Mensal'
            : message.contains('hora') || message.contains('hour')
            ? 'Primeira hora'
            : message.contains('cep') || message.contains('postal')
            ? 'CEP'
            : null;
        if (field != null) setState(() => invalidField = field);
      }
      await _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  ManagedParkingModel _buildParking() {
    final total = _sumSpots();
    final covered = _int(coveredController, 'Cobertas');
    final uncovered = _int(uncoveredController, 'Descobertas');
    final available = _int(availableController, 'Disponíveis');
    final arrivalTolerance = _int(
      arrivalToleranceController,
      'Tolerância de chegada',
    );
    final vip = _int(vipController, 'VIP');
    final large = _int(largeController, 'Carro grande');
    final bus = _int(busController, 'Ônibus');
    final pickup = _int(pickupController, 'Picape');

    if (total <= 0 || available > total) {
      throw Exception('Informe total positivo e disponibilidade até o total.');
    }

    if (arrivalTolerance < 1 || arrivalTolerance > 120) {
      throw Exception('Tolerância deve ficar entre 1 e 120 minutos.');
    }

    final street = _required(streetController, 'Nome da rua');
    final number = _required(numberController, 'Número');
    final neighborhood = _required(neighborhoodController, 'Bairro');
    final city = _required(cityController, 'Cidade');
    final fullAddress = '$street, $number, $neighborhood, $city';
    addressController.text = fullAddress;

    return ManagedParkingModel(
      id: widget.parking?.id,
      name: _required(nameController, 'Nome'),
      address: fullAddress,
      street: street,
      number: number,
      neighborhood: neighborhood,
      postalCode: cepController.text.trim().isEmpty
          ? null
          : cepController.text.trim(),
      city: city,
      lat: _double(latController, 'Latitude'),
      lng: _double(lngController, 'Longitude'),
      totalSpots: total,
      arrivalToleranceMinutes: arrivalTolerance,
      availableSpots: available,
      coveredSpots: covered,
      uncoveredSpots: uncovered,
      vipSpots: vip,
      largeSpots: large,
      busSpots: bus,
      pickupSpots: pickup,
      hasVipSpots: vip > 0,
      has24hGate: has24hGate,
      workRegime: workRegime,
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
      categoryPricing: {
        for (final entry in specialPricing.entries)
          if (_countFor(entry.key) > 0) entry.key: _pricing(entry.value),
      },
      operatingHours: operatingHours,
    );
  }

  int _countFor(String key) => switch (key) {
    'vip' => _int(vipController, 'VIP'),
    'large' => _int(largeController, 'Carro grande'),
    'bus' => _int(busController, 'Ônibus'),
    _ => _int(pickupController, 'Picape'),
  };

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
    if (value.isEmpty) {
      throw _FieldValidationException(label, 'Informe $label.');
    }
    return value;
  }

  int _int(TextEditingController controller, String label) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value < 0) {
      throw _FieldValidationException(label, 'Informe $label corretamente.');
    }
    return value;
  }

  double _double(TextEditingController controller, String label) {
    final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite) {
      throw _FieldValidationException(label, 'Informe $label corretamente.');
    }
    return value;
  }

  Future<void> _showMessage(String message) async {
    await ApiFeedback.show(context, message);
  }
}

class _FieldValidationException implements Exception {
  final String field;
  final String message;
  const _FieldValidationException(this.field, this.message);

  @override
  String toString() => message;
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
  final String? invalidField;

  const _PricingSection({
    required this.title,
    required this.controllers,
    this.invalidField,
  });

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
        decoration: InputDecoration(
          labelText: label,
          prefixText: 'R\$ ',
          errorText: invalidField == label ? 'Corrija este campo' : null,
        ),
      ),
    );
  }
}
