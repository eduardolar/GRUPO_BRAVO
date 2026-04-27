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
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
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
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutQuart),
          );
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
          final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          );
          final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutQuart),
          );
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
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeIn,
            ),
            child: child,
          );
        },
      );
}
