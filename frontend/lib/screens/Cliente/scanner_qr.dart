import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // IMPORTANTE: añade provider
import 'package:frontend/core/colors_style.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:frontend/providers/pedido_provider.dart'; // Tu provider de estado

class QRScanner extends StatefulWidget {
  const QRScanner({super.key});

  @override
  State<QRScanner> createState() => _QRScannerState();
}

class _QRScannerState extends State<QRScanner> {
  bool _yaDetectado = false;

  // --- LÓGICA CENTRALIZADA PARA PROCESAR EL CÓDIGO ---
  void _vincularMesa(String code) {
    if (_yaDetectado) return;
    setState(() => _yaDetectado = true);

    // Guardamos el ID en el Provider para que toda la app lo sepa
    final pedidoProv = Provider.of<PedidoProvider>(context, listen: false);
    pedidoProv.setMesa(code);

    // Feedback visual para el usuario
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mesa $code vinculada con éxito'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    // Regresamos a la pantalla anterior (Home o Menú)
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.iconPrimary),
        title: const Text(
          'VINCULAR MESA',
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
                    final barcode = capture.barcodes.first;
                    final String? code = barcode.rawValue;
                    if (code != null) {
                      // Usamos nuestra nueva función
                      _vincularMesa(code);
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
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
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
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Código de mesa'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            hintText: 'Introduce el código (ej: Mesa 1)',
          ),
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
                Navigator.pop(ctx); // Cierra el diálogo
                _vincularMesa(value); // Vincula la mesa
              }
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}
