import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:frontend/components/trabajador/bravo_splash.dart';
import 'package:frontend/core/app_routes.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/trabajador/Pedidos/gestion_pedidos.dart';
import 'package:frontend/screens/trabajador/servicio_trabajador/modificar_comanda.dart';
import 'package:frontend/screens/trabajador/servicio_trabajador/sacar_cuenta.dart';
import 'package:frontend/screens/trabajador/servicio_trabajador/seleccion_mesa.dart';
import 'package:frontend/screens/trabajador/appbar_trabajador.dart';

const BorderRadius _kRadius = BorderRadius.all(Radius.circular(12));

class ServicioTrabajador extends StatefulWidget {
  const ServicioTrabajador({super.key});

  @override
  State<ServicioTrabajador> createState() => _ServicioTrabajadorState();
}

class _ServicioTrabajadorState extends State<ServicioTrabajador> {
  bool _isAppReady = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 850),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_isAppReady),
          child: _isAppReady
              ? const _ServicioContent()
              : BravoSplash(
                  onFinished: () => setState(() => _isAppReady = true),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CONTENIDO PRINCIPAL
// ─────────────────────────────────────────────────────────────
class _ServicioContent extends StatelessWidget {
  const _ServicioContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: const TrabajadorAppBar(title: 'SERVICIO'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(children: const [_HeroSectionServicio(), _FooterQuote()]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HERO SECTION
// ─────────────────────────────────────────────────────────────
class _HeroSectionServicio extends StatelessWidget {
  const _HeroSectionServicio();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWeb = screenWidth > 600;
    final heroHeight = (screenHeight * (isWeb ? 0.85 : 0.75)).clamp(540.0, 920.0);

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          width: screenWidth,
          height: heroHeight,
          child: Image.asset(
            'assets/images/Bravo restaurante.jpg',
            fit: BoxFit.cover,
          ),
        ),

        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.3, 0.7, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                  AppColors.background,
                ],
              ),
            ),
          ),
        ),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBadge(),
                  const SizedBox(height: 24),

                  const Text(
                    "Panel de servicio",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      color: Colors.white,
                      fontSize: 38,
                      height: 1.1,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 15)],
                    ),
                  ),

                  const SizedBox(height: 35),

                  const _ActionButtonsServicio(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.button, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'GESTIÓN DE SERVICIO',
        style: TextStyle(
          color: AppColors.line,
          fontSize: 10,
          letterSpacing: 4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTONES DE ACCIÓN (Comanda / Cuenta)
// ─────────────────────────────────────────────────────────────
class _ActionButtonsServicio extends StatelessWidget {
  const _ActionButtonsServicio();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BotonAccion(
          icon: Icons.check_circle_outline,
          label: "Pedidos listos",
          isPrimary: true,
          onPressed: () => Navigator.push(
            context,
            // Atajo a Gestión de Pedidos abierto directamente en el tab Listos
            AppRoute.slide(const GestionPedidos(initialTab: 1)),
          ),
        ),
        _BotonAccion(
          icon: Icons.restaurant_menu_outlined,
          label: "Comanda",
          onPressed: () {
            Navigator.push(
              context,
              AppRoute.slide(const SeleccionMesa()),
            );
          },
        ),
        _BotonAccion(
          icon: Icons.edit_outlined,
          label: "Modificar comanda",
          onPressed: () {
            Navigator.push(
              context,
              AppRoute.slide(const ModificarComanda()),
            );
          },
        ),
        _BotonAccion(
          icon: Icons.calculate_outlined,
          label: "Sacar la cuenta",
          onPressed: () {
            Navigator.push(
              context,
              AppRoute.slide(const SacarCuenta()),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTÓN MODULAR (igual al de HomeTrabajador)
// ─────────────────────────────────────────────────────────────
class _BotonAccion extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _BotonAccion({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final fondo = isPrimary
        ? AppColors.button
        : Colors.black.withValues(alpha: 0.25);

    final boton = Material(
      color: fondo,
      borderRadius: _kRadius,
      elevation: isPrimary ? 4 : 0,
      shadowColor: Colors.black54,
      child: InkWell(
        onTap: onPressed,
        borderRadius: _kRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: _kRadius,
            border: isPrimary ? null : Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.white54,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: isPrimary
          ? boton
          : ClipRRect(
              borderRadius: _kRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: boton,
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FOOTER
// ─────────────────────────────────────────────────────────────
class _FooterQuote extends StatelessWidget {
  const _FooterQuote();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          margin: const EdgeInsets.fromLTRB(24, 20, 24, 60),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: _kRadius,
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              Icon(
                Icons.format_quote,
                color: AppColors.button.withValues(alpha: 0.4),
                size: 30,
              ),
              const SizedBox(height: 16),
              const Text(
                "Excelencia en cada mesa.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
