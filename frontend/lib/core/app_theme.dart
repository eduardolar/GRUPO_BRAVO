import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors_style.dart';

// Escala de motion centralizada (usada en AnimatedSwitcher, AnimatedContainer…)
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 380);
  static const curve = Curves.easeOutCubic;
}

abstract final class AppTheme {
  // ── Escala tipográfica ─────────────────────────────────────────────────────
  //
  // Dos familias:
  //   • Playfair Display → roles de display / headline (editorial, títulos)
  //   • Manrope          → roles de title / body / label  (UI funcional)
  //
  static TextTheme get _textTheme {
    final playfair = GoogleFonts.playfairDisplay;
    final manrope = GoogleFonts.manrope;

    return TextTheme(
      // Display — hero, banners grandes
      displayLarge: playfair(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
      displayMedium: playfair(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      displaySmall: playfair(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),

      // Headline — títulos de pantalla, secciones
      headlineLarge: playfair(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
      headlineMedium: playfair(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
      headlineSmall: manrope(fontSize: 16, fontWeight: FontWeight.w700),

      // Title — cabeceras de tarjeta, tabs
      titleLarge: manrope(fontSize: 15, fontWeight: FontWeight.w600),
      titleMedium: manrope(fontSize: 14, fontWeight: FontWeight.w500),
      titleSmall: manrope(fontSize: 13, fontWeight: FontWeight.w500),

      // Body — texto de párrafo
      bodyLarge: manrope(fontSize: 15, fontWeight: FontWeight.w400),
      bodyMedium: manrope(fontSize: 13, fontWeight: FontWeight.w400),
      bodySmall: manrope(fontSize: 11, fontWeight: FontWeight.w400),

      // Label — botones, chips, etiquetas
      labelLarge: manrope(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
      labelMedium: manrope(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
      labelSmall: manrope(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }

  // ── ColorScheme ────────────────────────────────────────────────────────────
  static const ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.button, // burdeos #800020
    onPrimary: Colors.white,
    secondary: AppColors.sombra, // burdeos oscuro #660019
    onSecondary: Colors.white,
    surface: AppColors.background, // blanco cálido #FBF9F6
    onSurface: AppColors.textPrimary, // casi negro #2D2D2D
    error: AppColors.error,
    onError: Colors.white,
  );

  // ── ElevatedButtonTheme ────────────────────────────────────────────────────
  // Coincide con PrimaryButton: burdeos lleno, sin esquinas redondeadas.
  static final ElevatedButtonThemeData _elevatedButtonTheme =
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.button,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.button.withValues(alpha: 0.5),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      );

  // ── InputDecorationTheme ───────────────────────────────────────────────────
  // Coincide con EntradaTexto: fondo panel, borde line, foco burdeos, r=15.
  static final InputDecorationTheme _inputDecorationTheme =
      InputDecorationTheme(
        filled: true,
        fillColor: AppColors.panel,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        errorStyle: const TextStyle(color: AppColors.error),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.button, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      );

  // ── AppBarTheme ────────────────────────────────────────────────────────────
  static AppBarTheme _appBarTheme(TextTheme tt) => AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    iconTheme: const IconThemeData(color: Colors.white),
    titleTextStyle: tt.headlineMedium?.copyWith(
      color: AppColors.textAppBar,
      letterSpacing: 2.0,
    ),
  );

  // ── ThemeData público ──────────────────────────────────────────────────────
  static ThemeData get light {
    final tt = _textTheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: _colorScheme,
      textTheme: tt,
      elevatedButtonTheme: _elevatedButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      appBarTheme: _appBarTheme(tt),
      scaffoldBackgroundColor: AppColors.background,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.button,
        selectionHandleColor: AppColors.button,
      ),
      dividerColor: AppColors.line,
    );
  }
}
