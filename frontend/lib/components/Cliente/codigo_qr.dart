import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/Cliente/scanner_qr.dart';
import 'package:frontend/screens/Cliente/login_screen.dart';
import 'package:frontend/services/api_service.dart';

class CodigoQr extends StatefulWidget {
  const CodigoQr({super.key});

  @override
  State<CodigoQr> createState() => _CodigoQrState();
}

class _CodigoQrState extends State<CodigoQr> {
  @override
  Widget build(BuildContext context) {
    //AÑADO PADDING
    return Padding(
      padding: const EdgeInsets.all(16),
      //WIDGET QUE CONVIERTE EL CONTAINER EN BOTON
      child: GestureDetector(
        onTap: () async {
          //VENTANA SCANNER QR
          final resultado = await Navigator.push<String>(
            context,
            MaterialPageRoute(builder: (context) => const QRScanner()),
          );

          if (resultado != null && mounted) {
            try {
              final mesa = await ApiService.validarQrMesa(codigoQr: resultado);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Mesa ${mesa['numero_mesa']} detectada'),
                  backgroundColor: AppColors.button,
                  duration: const Duration(seconds: 2),
                ),
              );
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('QR no válido: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.gold),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            children: [
              //ICONO DEL QR
              Icon(
                Icons.qr_code_sharp,
                size: 100,
                color: AppColors.iconPrimary,
              ),
              //BOTON DE QR SCAN
              Text(
                "QR",
                style: TextStyle(fontSize: 32, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
