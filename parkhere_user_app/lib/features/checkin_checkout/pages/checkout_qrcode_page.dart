import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

class CheckoutQRCodePage extends StatefulWidget {
  const CheckoutQRCodePage({super.key});

  @override
  State<CheckoutQRCodePage> createState() => _CheckoutQRCodePageState();
}

class _CheckoutQRCodePageState extends State<CheckoutQRCodePage> {

  late String qrData;
  late Timer timer;
  int secondsRemaining = 120; // ⏳ 2 minutos de validade

  @override
  void initState() {
    super.initState();
    _generateQrData();
    _startCountdown();
  }

  void _generateQrData() {
    final uuid = const Uuid().v4();

    final payload = {
      "token": uuid,
      "generated_at": DateTime.now().toIso8601String(),
      "type": "checkout",
    };

    qrData = jsonEncode(payload);
  }

  void _startCountdown() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsRemaining == 0) {
        t.cancel();
      } else {
        setState(() {
          secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return "$minutes:${secs.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {

    final expired = secondsRemaining == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("QR Code de Saída"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            if (!expired) ...[
              const Text(
                "Apresente este QR Code na saída",
                style: TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 24),

              QrImageView(
                data: qrData,
                size: 250,
              ),

              const SizedBox(height: 24),

              Text(
                "Expira em ${_formatTime(secondsRemaining)}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],

            if (expired) ...[
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 60,
              ),
              const SizedBox(height: 16),
              const Text(
                "QR Code expirado",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    secondsRemaining = 120;
                    _generateQrData();
                    _startCountdown();
                  });
                },
                child: const Text("Gerar novo QR"),
              )
            ],

            const SizedBox(height: 40),

            const Text(
              "Por segurança, este código é válido por tempo limitado.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}