import 'package:flutter/material.dart';
import 'package:frontend/core/app_snackbar.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/cocinero/pedidos_cocina_screen.dart';

/// Pantalla de entrada del rol cocinero.
///
/// Decisión A2: se mantiene el archivo para no tocar login_screen.dart,
/// totp_login_screen.dart y verificacion_screen.dart (fuera del scope).
/// Se eliminó el splash artificial de 2 s (_SimpleSplash con Future.delayed)
/// y la pantalla ya no es una redirección ciega: muestra un acceso directo
/// e inmediato a los pedidos activos.
class HomeCocinero extends StatelessWidget {
  const HomeCocinero({super.key});

  @override
  Widget build(BuildContext context) {
    // PopScope: el cocinero entra aquí tras un pushAndRemoveUntil del login,
    // así que la pila no tiene nada debajo. El "atrás" del sistema dejaría
    // la pantalla en blanco; lo bloqueamos y guiamos al botón de salida.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        showAppInfo(
          context,
          'Usa el botón "Cerrar sesión" del menú para salir',
        );
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / identidad
                  Image.asset(
                    'assets/images/Bravo restaurante.jpg',
                    width: 120,
                    semanticLabel: 'Logo Restaurante Bravo',
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'ÁREA DE COCINA',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Panel de\ncocina',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      color: AppColors.textPrimary,
                      fontSize: 36,
                      height: 1.15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Botón principal — acceso directo, sin pasos intermedios
                  Semantics(
                    button: true,
                    label: 'Ver pedidos activos de cocina',
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PedidosCocinaScreen(),
                          ),
                        ),
                        icon: const Icon(
                          Icons.receipt_long_outlined,
                          size: 20,
                        ),
                        label: const Text(
                          'VER PEDIDOS ACTIVOS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.button,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
