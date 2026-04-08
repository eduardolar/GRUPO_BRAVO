import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScanner extends StatefulWidget {
  const QRScanner({super.key});

  @override
  State<QRScanner> createState() => _QRScannerState();
}

class _QRScannerState extends State<QRScanner> {
  String? qrText;
  bool _yaDetectado = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.iconPrimary),
        title: const Text(
          'ESCANEAR QR',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    if (_yaDetectado) return;
                    final barcode = capture.barcodes.first;
                    final String? code = barcode.rawValue;

                    if (code != null) {
                      _yaDetectado = true;
                      Navigator.pop(context, code);
                    }
                  },
                ),
                // Marco visual de escaneo
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.gold, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Apunta al código QR de la mesa',
                  style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _introducirCodigoManual,
                  icon: const Icon(Icons.keyboard, color: AppColors.button),
                  label: const Text(
                    'Introducir código manual',
                    style: TextStyle(color: AppColors.button),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _introducirCodigoManual() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Código de mesa'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Introduce el código de la mesa',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(ctx);
              Navigator.pop(context, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(ctx);
                Navigator.pop(context, value);
              }
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}
