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
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_handled || capture.barcodes.isEmpty) return;
              final value = capture.barcodes.first.rawValue;
              if (value == null || value.isEmpty) return;
              _handled = true;
              Navigator.pop(context, value);
            },
          ),
          IgnorePointer(child: CustomPaint(painter: _ScannerOverlayPainter())),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Posicione o código dentro da área indicada',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.only(bottom: 32),
                  child: Text(
                    'Mantenha o celular firme e aproxime ou afaste até focar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cutout = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * .82,
      height: 130,
    );
    final shade = Paint()..color = Colors.black54;
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(cutout, const Radius.circular(18)));
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, shade);
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutout, const Radius.circular(18)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) => false;
}
