import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ler código de barras')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled || capture.barcodes.isEmpty) return;
          final value = capture.barcodes.first.rawValue;
          if (value == null || value.isEmpty) return;
          _handled = true;
          Navigator.pop(context, value);
        },
      ),
    );
  }
}
