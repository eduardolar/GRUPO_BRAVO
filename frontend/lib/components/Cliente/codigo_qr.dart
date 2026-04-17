import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/screens/cliente/scanner_qr.dart';
import 'package:frontend/screens/cliente/login_screen.dart';
import 'package:frontend/models/destino_login.dart';
import 'package:frontend/screens/cliente/menu_screen.dart';
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';

class CodigoQr extends StatefulWidget {
  const CodigoQr({super.key});

  @override
  State<CodigoQr> createState() => _CodigoQrState();
}

class _CodigoQrState extends State<CodigoQr> {
  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return GestureDetector(
      onTap: () async {
        final codigoQr = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (context) => const QRScanner()),
        );
        if (codigoQr == null || !mounted) return;

        try {
          final resultado = await ApiService.validarQrMesa(codigoQr: codigoQr);
          final mesaId = resultado['mesa_id'] as String;
          final numeroMesa = resultado['numero_mesa'] is int
              ? resultado['numero_mesa'] as int
              : int.tryParse(resultado['numero_mesa'].toString()) ?? 0;

          if (!mounted) return;
          cart.asignarMesa(mesaId: mesaId, numeroMesa: numeroMesa);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mesa $numeroMesa asignada correctamente'),
              backgroundColor: Colors.green,
            ),
          );

          // Navegar automáticamente: login → menú (o directo al menú si ya está autenticado)
          if (!mounted) return;
          final auth = Provider.of<AuthProvider>(context, listen: false);
          if (auth.estaAutenticado) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MenuScreen()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LoginScreen(destino: DestinoLogin.menu),
              ),
            );
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('QR no válido: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF800020),
          border: Border.all(color: const Color(0xFFA6405A)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          
            Container(
              width: 3,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 16),
            // Icono
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF660019),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA6405A)),
              ),
              child: const Icon(
                Icons.qr_code_sharp,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // Textos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    cart.tienemesa
                        ? "Mesa ${cart.numeroMesa}"
                        : "Escanear QR",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cart.tienemesa
                        ? "Toca para cambiar de mesa"
                        : "Acceder a la mesa con código",
                    style: const TextStyle(
                      color: Color(0xFFEFEBE9),
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            // Flecha dorada
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.7),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
