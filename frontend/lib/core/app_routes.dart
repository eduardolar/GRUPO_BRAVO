// ============================================================================
// frontend/lib/core/app_routes.dart
// ----------------------------------------------------------------------------
// Transiciones de pantalla centralizadas.
//
// En lugar de usar el `MaterialPageRoute` por defecto (que usa una sola
// transición para todo), aquí elegimos la animación según la INTENCIÓN
// narrativa del cambio de pantalla. Esto le da a la app una "sensación"
// más cuidada y coherente.
//
// Uso típico:
//   Navigator.push(context, AppRoute.slide(SiguienteScreen()));
//   Navigator.push(context, AppRoute.slideUp(LoginScreen()));
//
// Cada método encapsula `PageRouteBuilder` con su propia curva, duración y
// transform. Al estar centralizadas, cambiar el "tempo" de toda la app es
// editar solo este archivo.
// ============================================================================
import 'package:flutter/material.dart';

/// Transiciones de pantalla centralizadas.
///
/// Cada tipo comunica intención de navegación:
///   slide    — avance lineal (home → menú, home → scanner)
///   slideUp  — pantallas modales/auth (login, registro, perfil, QR)
///   reveal   — momento de alto impacto (post-login, pedido confirmado)
///   fade     — transición neutra/rápida (rutas ocultas, laterales)
class AppRoute {
  AppRoute._();

  // ── SLIDE ────────────────────────────────────────────────────────────────
  // Deslizamiento sutil desde la derecha + fade.
  // Comunica "estás avanzando en el flujo".
  static PageRoute<T> slide<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(0.06, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
        ),
      );
      return FadeTransition(
        opacity: opacity,
        child: SlideTransition(position: offset, child: child),
      );
    },
  );

  // ── SLIDE UP ─────────────────────────────────────────────────────────────
  // La pantalla emerge desde abajo con un fade rápido.
  // Comunica "esto es una capa sobre lo anterior" (auth, modales, cámara).
  static PageRoute<T> slideUp<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(0, 0.055),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
      final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
        ),
      );
      return FadeTransition(
        opacity: opacity,
        child: SlideTransition(position: offset, child: child),
      );
    },
  );

  // ── REVEAL ───────────────────────────────────────────────────────────────
  // Fade con ligero zoom de profundidad (0.96 → 1.0).
  // Comunica "entraste a un nuevo espacio" — post-login, pedido confirmado.
  static PageRoute<T> reveal<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final opacity = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));
      final scale = Tween<double>(
        begin: 0.96,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
      return FadeTransition(
        opacity: opacity,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );

  // ── FADE ─────────────────────────────────────────────────────────────────
  // Crossfade limpio y rápido.
  // Para transiciones neutras, rutas ocultas o accesos auxiliares.
  static PageRoute<T> fade<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
        child: child,
      );
    },
  );
}

/// Entrada suave del contenido de una pantalla: fade + ligero deslizamiento
/// hacia arriba. Pensado para envolver el body de Scaffold y darle al
/// trabajador (y otras zonas) una aparición elegante sin animaciones largas
/// estilo splash.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 380),
    this.delay = Duration.zero,
    this.offset = 18,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration + delay,
      curve: Interval(
        delay.inMilliseconds / (duration.inMilliseconds + delay.inMilliseconds + 1),
        1.0,
        curve: Curves.easeOutCubic,
      ),
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * offset),
          child: c,
        ),
      ),
      child: child,
    );
  }
}
