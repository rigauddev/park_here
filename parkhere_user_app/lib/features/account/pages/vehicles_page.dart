import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/vehicle_catalog.dart';
import '../models/account_models.dart';
import '../providers/account_provider.dart';

class VehiclesPage extends ConsumerStatefulWidget {
  const VehiclesPage({super.key});

  @override
  ConsumerState<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends ConsumerState<VehiclesPage> {
  final nicknameController = TextEditingController(text: 'Meu carro');
  final plateController = TextEditingController();
  final colorController = TextEditingController();
  final bicyclePartsController = TextEditingController();

  VehicleType vehicleType = VehicleType.car;
  String? selectedBrand;
  String? selectedModel;
  String? vehicleDocumentFileName;
  VehicleOwnershipType ownershipType = VehicleOwnershipType.owner;

  @override
  void dispose() {
    nicknameController.dispose();
    plateController.dispose();
    colorController.dispose();
    bicyclePartsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    final catalog = vehicleType == VehicleType.motorcycle
        ? motorcycleCatalog
        : vehicleCatalog;
    final models = selectedBrand == null
        ? const <String>[]
        : catalog[selectedBrand] ?? const <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Veiculos')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Cadastrar veiculo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Para realizar uma reserva, escolha um veiculo ativo.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 18),
          _field(nicknameController, 'Apelido do veiculo', Icons.sell_outlined),
          DropdownButtonFormField<VehicleType>(
            initialValue: vehicleType,
            decoration: const InputDecoration(labelText: 'Tipo de veículo', prefixIcon: Icon(Icons.directions_car_outlined)),
            items: const [
              DropdownMenuItem(value: VehicleType.car, child: Text('Carro')),
              DropdownMenuItem(value: VehicleType.motorcycle, child: Text('Motocicleta')),
              DropdownMenuItem(value: VehicleType.bicycle, child: Text('Bicicleta')),
            ],
            onChanged: (value) => setState(() {
              vehicleType = value ?? VehicleType.car;
              selectedBrand = null;
              selectedModel = null;
            }),
          ),
          _field(plateController, vehicleType == VehicleType.bicycle ? 'Número de identificação' : 'Placa', Icons.pin_outlined),
          if (vehicleType == VehicleType.bicycle)
            _field(bicyclePartsController, 'Peças e características (opcional)', Icons.build_outlined),
          if (vehicleType != VehicleType.bicycle) DropdownButtonFormField<String>(
            initialValue: selectedBrand,
            decoration: const InputDecoration(
              labelText: 'Marca',
              prefixIcon: Icon(Icons.directions_car_filled_outlined),
            ),
            items: [
              for (final brand in catalog.keys)
                DropdownMenuItem(value: brand, child: Text(brand)),
            ],
            onChanged: (value) {
              setState(() {
                selectedBrand = value;
                selectedModel = null;
              });
            },
          ),
          const SizedBox(height: 12),
          if (vehicleType != VehicleType.bicycle) DropdownButtonFormField<String>(
            initialValue: selectedModel,
            decoration: const InputDecoration(
              labelText: 'Modelo',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              for (final model in models)
                DropdownMenuItem(value: model, child: Text(model)),
            ],
            onChanged: models.isEmpty
                ? null
                : (value) => setState(() => selectedModel = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: colorController.text.isEmpty
                ? null
                : colorController.text,
            decoration: const InputDecoration(
              labelText: 'Cor',
              prefixIcon: Icon(Icons.palette_outlined),
            ),
            items: [
              for (final color in _vehicleColors)
                DropdownMenuItem(value: color, child: Text(color)),
            ],
            onChanged: (value) => colorController.text = value ?? '',
          ),
          SegmentedButton<VehicleOwnershipType>(
            segments: const [
              ButtonSegment(
                value: VehicleOwnershipType.owner,
                label: Text('Proprietario'),
                icon: Icon(Icons.verified_user_outlined),
              ),
              ButtonSegment(
                value: VehicleOwnershipType.rented,
                label: Text('Alugado'),
                icon: Icon(Icons.assignment_ind_outlined),
              ),
            ],
            selected: {ownershipType},
            onSelectionChanged: (value) {
              setState(() => ownershipType = value.first);
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickVehicleDocument,
            icon: Icon(
              vehicleDocumentFileName == null
                  ? Icons.upload_file_outlined
                  : Icons.check_circle,
            ),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                vehicleDocumentFileName ?? 'Anexar documento do carro',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saveVehicle,
            icon: const Icon(Icons.add),
            label: const Text('Salvar veiculo ativo'),
          ),
          const SizedBox(height: 28),
          if (account.vehicles.isNotEmpty) ...[
            Text(
              'Veiculos cadastrados',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            for (final vehicle in account.vehicles)
              _VehicleTile(
                vehicle: vehicle,
                onSetActive: () {
                  ref
                      .read(accountProvider.notifier)
                      .setActiveVehicle(vehicle.id);
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  Future<void> _pickVehicleDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );

    final file = result?.files.single;
    if (file == null) return;

    setState(() => vehicleDocumentFileName = file.name);
  }

  Future<void> _saveVehicle() async {
    if (nicknameController.text.trim().isEmpty ||
        plateController.text.trim().isEmpty ||
        (vehicleType != VehicleType.bicycle && (selectedBrand == null || selectedModel == null)) ||
        colorController.text.trim().isEmpty ||
        vehicleDocumentFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha os dados e anexe o documento do carro.'),
        ),
      );
      return;
    }

    await ref
        .read(accountProvider.notifier)
        .addVehicle(
          VehicleModel(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            nickname: nicknameController.text.trim(),
            plate: plateController.text.trim().toUpperCase(),
            brand: vehicleType == VehicleType.bicycle ? 'Bicicleta' : selectedBrand!,
            model: vehicleType == VehicleType.bicycle ? 'Bicicleta' : selectedModel!,
            color: colorController.text.trim(),
            documentFileName: vehicleDocumentFileName,
            ownershipType: ownershipType,
            isActive: true,
            vehicleType: vehicleType,
            bicycleParts: bicyclePartsController.text.trim().isEmpty ? null : bicyclePartsController.text.trim(),
          ),
        );

    if (!mounted) return;

    setState(() {
      nicknameController.text = 'Meu carro';
      plateController.clear();
      colorController.clear();
      selectedBrand = null;
      selectedModel = null;
      vehicleDocumentFileName = null;
      ownershipType = VehicleOwnershipType.owner;
      vehicleType = VehicleType.car;
      bicyclePartsController.clear();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Veiculo salvo como ativo.')));
  }
}

const _vehicleColors = [
  'Branco',
  'Preto',
  'Prata',
  'Cinza',
  'Grafite',
  'Vermelho',
  'Azul',
  'Verde',
  'Amarelo',
  'Marrom',
  'Bege',
  'Laranja',
  'Roxo',
  'Dourado',
  'Outro',
];

class _VehicleTile extends StatelessWidget {
  final VehicleModel vehicle;
  final VoidCallback onSetActive;

  const _VehicleTile({required this.vehicle, required this.onSetActive});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: vehicle.isActive
              ? AppTheme.primary
              : AppTheme.primary.withValues(alpha: 0.12),
          foregroundColor: vehicle.isActive ? Colors.white : AppTheme.primary,
          child: const Icon(Icons.directions_car_filled_outlined),
        ),
        title: Text('${vehicle.nickname} - ${vehicle.plate}'),
        subtitle: Text('${vehicle.brand} ${vehicle.model} | ${vehicle.color}'),
        trailing: vehicle.isActive
            ? const Icon(Icons.check_circle, color: AppTheme.success)
            : TextButton(onPressed: onSetActive, child: const Text('Ativar')),
      ),
    );
  }
}
