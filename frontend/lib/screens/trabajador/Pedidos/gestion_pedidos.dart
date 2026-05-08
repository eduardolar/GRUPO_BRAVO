import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:frontend/components/trabajador/bravo_splash.dart';
import 'package:frontend/core/app_routes.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/core/app_snackbar.dart';
import 'package:frontend/screens/trabajador/Pedidos/local_domicilio.dart';
import 'package:frontend/screens/trabajador/Pedidos/pedidos_listos_screen.dart';
import 'package:frontend/screens/trabajador/appbar_trabajador.dart';

const BorderRadius _kRadius = BorderRadius.all(Radius.circular(12));

class GestionPedidos extends StatefulWidget {
  const GestionPedidos({super.key});

  @override
  State<GestionPedidos> createState() => _GestionPedidosState();
}

class _GestionPedidosState extends State<GestionPedidos> {
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
              ? const _PedidosContent()
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
class _PedidosContent extends StatelessWidget {
  const _PedidosContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: const TrabajadorAppBar(title: 'GESTIÓN DE PEDIDOS'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(children: const [_HeroSectionPedidos(), _FooterQuote()]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HERO SECTION
// ─────────────────────────────────────────────────────────────
class _HeroSectionPedidos extends StatelessWidget {
  const _HeroSectionPedidos();

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
                    "Panel de pedidos",
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

                  const _ActionButtonsPedidos(),
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
        'GESTIÓN DE PEDIDOS',
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
// BOTONES DE ACCIÓN
// ─────────────────────────────────────────────────────────────
class _ActionButtonsPedidos extends StatelessWidget {
  const _ActionButtonsPedidos();

  void _noDisponible(BuildContext context, String accion) {
    showAppInfo(context, '$accion: No disponible — usa el panel de admin');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BotonAccion(
          icon: Icons.add_shopping_cart_outlined,
          label: "Crear un pedido",
          isPrimary: true,
          onPressed: () {
            Navigator.push(
              context,
              AppRoute.slide(const SeleccionTipoPedido()),
            );
          },
        ),
        _BotonAccion(
          icon: Icons.list_alt_outlined,
          label: "Pedidos listos",
          onPressed: () {
            Navigator.push(
              context,
              AppRoute.slide(const PedidosListosScreen()),
            );
          },
        ),
        _BotonAccion(
          icon: Icons.edit_outlined,
          label: "Modificar un pedido",
          onPressed: () => _noDisponible(context, 'Modificar un pedido'),
        ),
        _BotonAccion(
          icon: Icons.delete_outline,
          label: "Eliminar un pedido",
          onPressed: () => _noDisponible(context, 'Eliminar un pedido'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTÓN MODULAR
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
                "Organización y precisión en cada pedido.",
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
