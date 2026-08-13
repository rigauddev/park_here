import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/account_models.dart';
import '../providers/account_provider.dart';
import 'vehicles_page.dart';

class AccountSetupPage extends ConsumerStatefulWidget {
  const AccountSetupPage({super.key});

  @override
  ConsumerState<AccountSetupPage> createState() => _AccountSetupPageState();
}

class _AccountSetupPageState extends ConsumerState<AccountSetupPage> {
  final documentController = TextEditingController();

  DriverDocumentType documentType = DriverDocumentType.cnh;
  String? frontFileName;
  String? backFileName;

  @override
  void dispose() {
    documentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete seu cadastro'),
        actions: [
          TextButton(onPressed: _skip, child: const Text('Deixar para depois')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Documento do motorista',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Anexe RG ou CNH. Voce pode concluir essa etapa depois, mas para realizar uma reserva sera necessario ter um veiculo ativo.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 18),
          SegmentedButton<DriverDocumentType>(
            segments: const [
              ButtonSegment(value: DriverDocumentType.cnh, label: Text('CNH')),
              ButtonSegment(value: DriverDocumentType.rg, label: Text('RG')),
            ],
            selected: {documentType},
            onSelectionChanged: (value) {
              setState(() => documentType = value.first);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: documentController,
            decoration: const InputDecoration(
              labelText: 'Numero do documento',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          _AttachmentButton(
            title: 'Anexar frente do documento',
            fileName: frontFileName,
            onPressed: () => _pickDocumentFile(isFront: true),
          ),
          const SizedBox(height: 10),
          _AttachmentButton(
            title: 'Anexar verso do documento',
            fileName: backFileName,
            onPressed: () => _pickDocumentFile(isFront: false),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _saveDriverDocument,
            icon: const Icon(Icons.check),
            label: const Text('Salvar documento'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openVehicles,
            icon: const Icon(Icons.directions_car_filled_outlined),
            label: Text(
              account.hasActiveVehicle
                  ? 'Gerenciar veiculos'
                  : 'Cadastrar veiculo',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDocumentFile({required bool isFront}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );

    final file = result?.files.single;
    if (file == null) return;

    setState(() {
      if (isFront) {
        frontFileName = file.name;
      } else {
        backFileName = file.name;
      }
    });
  }

  Future<void> _saveDriverDocument() async {
    if (documentController.text.trim().isEmpty ||
        frontFileName == null ||
        backFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o numero e anexe frente e verso.'),
        ),
      );
      return;
    }

    await ref
        .read(accountProvider.notifier)
        .saveDriverDocument(
          DriverDocumentModel(
            type: documentType,
            number: documentController.text.trim(),
            frontFileName: frontFileName,
            backFileName: backFileName,
          ),
        );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Documento salvo.')));
  }

  void _openVehicles() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const VehiclesPage()));
  }

  void _skip() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tudo bem. Voce pode completar pelo menu Perfil.'),
      ),
    );
  }
}

class _AttachmentButton extends StatelessWidget {
  final String title;
  final String? fileName;
  final VoidCallback onPressed;

  const _AttachmentButton({
    required this.title,
    required this.fileName,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(fileName == null ? Icons.attach_file : Icons.check_circle),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(fileName ?? title, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
