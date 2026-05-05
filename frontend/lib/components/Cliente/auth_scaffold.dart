import 'package:flutter/material.dart';
import '../../core/colors_style.dart';

/// Scaffold compartido para todas las pantallas de autenticación.
/// Proporciona: fondo de imagen, overlay oscuro, SafeArea centrada
/// con ancho máximo, y botón de volver opcional.
class ClienteAuthScaffold extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool mostrarVolver;
  final VoidCallback? onVolver;

  const ClienteAuthScaffold({
    super.key,
    required this.child,
    this.maxWidth = 500,
    this.padding,
    this.mostrarVolver = true,
    this.onVolver,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Bravo restaurante.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: AppColors.shadow.withValues(alpha: 0.85)),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      padding ??
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                  child: child,
                ),
              ),
            ),
          ),
          if (mostrarVolver)
            Positioned(
              top: 20,
              left: 10,
              child: IconButton(
                tooltip: 'Volver',
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: onVolver ?? () => Navigator.pop(context),
              ),
            ),
        ],
      ),
    );
  }
}
