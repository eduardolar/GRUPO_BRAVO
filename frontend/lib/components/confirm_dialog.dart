// ============================================================================
// frontend/lib/components/confirm_dialog.dart
// ----------------------------------------------------------------------------
// Diálogo de confirmación reutilizable con estética "frosted glass":
// esquinas redondeadas (r=24), fondo semitransparente + blur, y botón de
// acción sólido. Mismo lenguaje visual que el modal de crear/editar sucursal.
//
// Uso:
//   final ok = await showConfirmDialog(
//     context,
//     titulo: 'Suspender sucursal',
//     mensaje: '¿Suspender "Bravo 1"? No se aceptarán nuevos pedidos.',
//     textoConfirmar: 'SUSPENDER',
//     colorConfirmar: AppColors.warning,
//   );
//   if (!ok) return;
// ============================================================================
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/colors_style.dart';

/// Muestra un diálogo de confirmación frosted-glass.
///
/// Devuelve `true` solo si el usuario pulsa el botón de confirmar; `false`
/// si cancela o cierra el diálogo tocando fuera.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String textoConfirmar,
  Color colorConfirmar = AppColors.primary,
  String textoCancelar = 'Cancelar',
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            decoration: BoxDecoration(
              // Fondo semitransparente. Más opaco que el modal de crear (0.6)
              // porque aquí no hay campos crema que iluminen el panel: con
              // poco contenido, a 0.6 se transparentaba el fondo oscuro.
              color: AppColors.background.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.line.withValues(alpha: 0.6)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  mensaje,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        textoCancelar,
                        style: GoogleFonts.manrope(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorConfirmar,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        textoConfirmar,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return resultado ?? false;
}
