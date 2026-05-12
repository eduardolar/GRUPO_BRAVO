import 'package:flutter/material.dart';

/// Paleta GRUPO BRAVO — WCAG 2.1 nivel AA (varios tokens llegan a AAA).
/// Mantiene la identidad burdeos + crema con tonos calibrados para contraste.
/// Los nombres antiguos (button, disp, noDisp, line, panel, etc.) se conservan
/// como aliases para no romper los 1500+ usos existentes.
class AppColors {
  // ── Fondos modo claro ──────────────────────────────────────────────────────
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7F4EF);
  static const Color surfaceAlt = Color(0xFFEBE5DB);
  static const Color panel = surface; // alias retro-compat

  // ── Líneas y bordes ────────────────────────────────────────────────────────
  static const Color lineSubtle = Color(0xFFD6CFC2);
  static const Color lineStrong = Color(0xFF8C8270);
  static const Color line = lineSubtle; // alias retro-compat

  // ── Marca burdeos ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6E001B);
  static const Color primaryHover = Color(0xFF4D0014);
  static const Color primaryAccent = Color(0xFFA6405A);
  static const Color button = primary; // alias retro-compat
  static const Color backgroundButton = primary; // alias retro-compat
  static const Color sombra = primaryHover; // alias retro-compat

  // ── Texto ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF525252);
  static const Color textTertiary = Color(0xFF6B6B6B);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textAppBar = Color(0xFFFFF8E1);

  // ── Iconos ─────────────────────────────────────────────────────────────────
  static const Color iconPrimary = textPrimary;
  static const Color iconOnPrimary = textOnPrimary;

  // ── Estados ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF0F7A2E);
  static const Color successBg = Color(0xFFDCF1E1);
  static const Color successText = Color(0xFF0B5A22);
  static const Color error = Color(0xFFC0182B);
  static const Color errorBg = Color(0xFFFBE0E3);
  static const Color errorText = Color(0xFF8C0E1F);
  static const Color warning = Color(0xFFA1591F);
  static const Color warningBg = Color(0xFFFDEBD2);
  static const Color warningText = Color(0xFF7A3F0E);
  static const Color info = Color(0xFF1956A6);
  static const Color infoBg = Color(0xFFDCE9F8);
  static const Color infoText = Color(0xFF0E3A75);

  // ── Lógica disponibilidad ──────────────────────────────────────────────────
  static const Color disp = success; // alias retro-compat (verde "disponible")
  static const Color noDisp = Color(0xFFA03A0A); // ocupado/no disponible
  static const Color surfacePending = Color(0xFF8A4310);

  // ── Foco accesible ─────────────────────────────────────────────────────────
  static const Color focusRing = Color(0xFFB26200);
  static const Color focusRingDark = Color(0xFFFFD24D);

  // ── Fondos oscuros (preparado para futuro modo oscuro) ─────────────────────
  static const Color backgroundDark = Color(0xFF0F0F10);
  static const Color surfaceDark = Color(0xFF1F1F22);
  static const Color bottomSheetBg = Color(0xFF0F0F10);

  // ── Third-party (guidelines) ───────────────────────────────────────────────
  static const Color paypal = Color(0xFF003087); // mejorado a 8.6:1
  static const Color googlePayGrey = Color(0xFF5F6368);
  static const Color googlePayGreen = Color(0xFF1A8E3E);
  // Google brand — letras coloreadas del logotipo "Google" (brand guidelines)
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleRed = Color(0xFFEA4335);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleGreen = Color(0xFF34A853);

  // ── Otros ──────────────────────────────────────────────────────────────────
  static const Color shadow = Color(0x66000000);
  static const Color successBackground = successBg; // alias retro-compat
  static const Color excludedIngredient = Color(0xFFD3717C);
  static const Color mesaSeleccionada = Color(0xFFB26200);

  // ── Tokens auxiliares ──────────────────────────────────────────────────────
  /// Crema muy suave — subtítulo sobre botones burdeos oscuros.
  static const Color textCream = Color(0xFFEFEBE9);
  /// Texto claro sobre fondos muy oscuros (ej. cupones super_admin).
  static const Color textOnDark = Color(0xFFEAEAEA);
  /// Gris medio iOS — texto secundario en paneles oscuros.
  static const Color textMidGrey = Color(0xFF8E8E93);
  /// Verde "abierto" — badge de estado restaurante abierto.
  static const Color successLight = Color(0xFF66BB6A);
  /// Naranja iOS — estado "advertencia suave" en catálogo masivo.
  static const Color warningLight = Color(0xFFFF9500);
  /// Verde iOS — estado "correcto" en catálogo masivo.
  static const Color successVibrant = Color(0xFF34C759);
}
