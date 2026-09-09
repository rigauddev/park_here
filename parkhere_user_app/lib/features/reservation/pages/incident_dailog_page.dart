import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class IncidentDialog extends StatefulWidget {
  const IncidentDialog({super.key});

  @override
  State<IncidentDialog> createState() => _IncidentDialogState();
}

class _IncidentDialogState extends State<IncidentDialog> {
  final TextEditingController _controller = TextEditingController();
  XFile? _image;

  Future<void> _takePhoto() async {
    final picker = ImagePicker();

    final photo = await picker.pickImage(
      source: ImageSource.camera, // 🔥 SOMENTE CÂMERA
    );

    if (photo != null) {
      setState(() => _image = photo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Reportar incidente"),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Descreva brevemente o ocorrido...",
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text("Anexar evidência"),
            ),
            if (_image != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Image.file(File(_image!.path), height: 120),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () {
            // enviar para backend futuramente
            Navigator.pop(context);
          },
          child: const Text("Enviar"),
        ),
      ],
    );
  }
}
