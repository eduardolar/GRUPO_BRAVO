import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:frontend/core/app_routes.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/trabajador/Pedidos/gestion_pedidos.dart';
import 'package:frontend/screens/trabajador/Reservas/gestion_reservas.dart';
import 'package:frontend/screens/trabajador/Stock/gestion_stock.dart';
import 'package:frontend/screens/trabajador/appbar_trabajador.dart';
import 'package:frontend/screens/trabajador/mi_turno_screen.dart';
import 'package:frontend/screens/trabajador/servicio_trabajador/seleccion_mesa.dart';

const String _kBackgroundAsset = 'assets/images/Bravo restaurante.jpg';

class HomeTrabajador extends StatelessWidget {
  const HomeTrabajador({super.key});

  @override
  Widget build(BuildContext context) {
    // PopScope bloquea el gesto "atrás" del sistema (Android/web).
    // La pila de navegación queda vacía tras pushAndRemoveUntil en login,
    // así que permitir pop dejaría pantalla en blanco. El trabajador sale
    // únicamente a través del botón de cerrar sesión en el AppBar.
    return const PopScope(
      canPop: false,
      child: _ContenidoHome(),
    );
  }
}

// ── CONTENIDO PRINCIPAL ──────────────────────────────────────────────────

class _ContenidoHome extends StatelessWidget {
  const _ContenidoHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const TrabajadorAppBar(title: "RESTAURANTE BRAVO"),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(_kBackgroundAsset),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.85),
              ],
            ),
          ),
          child: SafeArea(
            child: FadeSlideIn(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderSaludo(),
                    SizedBox(height: 28),
                    _GridOpciones(),
                    SizedBox(height: 24),
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

// ── Header con saludo (mismo patrón que admin_home_screen) ──────────────
class _HeaderSaludo extends StatelessWidget {
  const _HeaderSaludo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¡Hola, Trabajador!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¿Qué te gustaría gestionar hoy?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grid 2x2 de tarjetas de gestión (estilo admin) ────────────────────────
class _GridOpciones extends StatelessWidget {
  const _GridOpciones();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TrabajadorCard(
                title: 'Reservas',
                subtitle: 'Gestión del día',
                icon: Icons.event_available_outlined,
                destination: const GestionReservas(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TrabajadorCard(
                title: 'Pedidos',
                subtitle: 'Activos, listos y cobro',
                icon: Icons.receipt_long_outlined,
                destination: const GestionPedidos(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _TrabajadorCard(
                title: 'Mesas',
                subtitle: 'Plano del local',
                icon: Icons.table_restaurant_outlined,
                destination: const SeleccionMesa(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TrabajadorCard(
                title: 'Stock',
                subtitle: 'Avisar y agotar',
                icon: Icons.inventory_2_outlined,
                destination: const GestionStock(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Tarjeta full-width para acceso rápido a las stats personales del
        // turno actual (cuánto cobré hoy, cuántas mesas atendí, propinas).
        // Antes solo era accesible desde el icono de perfil.
        _TrabajadorCard(
          title: 'Mi turno',
          subtitle: 'Cobros, propinas y mesas atendidas hoy',
          icon: Icons.bar_chart_outlined,
          destination: const MiTurnoScreen(),
          isFullWidth: true,
        ),
      ],
    );
  }
}

// ── Tarjeta de menú con icono circular burdeos (mismo estilo admin) ──────
class _TrabajadorCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget destination;
  /// Layout horizontal con icono a la izquierda + título/subtítulo + arrow.
  /// Mismo formato que las cards full-width del admin (Mi local, Cierre,
  /// Contabilidad). Altura menor que las del grid.
  final bool isFullWidth;

  const _TrabajadorCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.destination,
    this.isFullWidth = false,
  });

  Widget _iconCircular() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.button.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.button.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Icon(icon, color: AppColors.button, size: 30),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: isFullWidth ? 120 : 180,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              highlightColor: AppColors.button.withValues(alpha: 0.1),
              splashColor: AppColors.button.withValues(alpha: 0.2),
              onTap: () => Navigator.push(
                context,
                AppRoute.slide(destination),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: isFullWidth
                    ? Row(
                        children: [
                          _iconCircular(),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 20,
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _iconCircular(),
                          const Spacer(),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
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

