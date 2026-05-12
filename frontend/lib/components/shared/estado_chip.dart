import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

/// Estados visuales para mesas, pedidos y stock. Cumple WCAG 1.4.1:
/// la información se transmite por color + icono + texto, no solo color.
enum EstadoMesa { disponible, ocupada, reservada, pendiente }

class EstadoChip extends StatelessWidget {
  final EstadoMesa estado;
  final String label;
  final double iconSize;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  const EstadoChip({
    super.key,
    required this.estado,
    required this.label,
    this.iconSize = 16,
    this.fontSize = 12,
    this.padding,
  });

  ({Color bg, Color fg, IconData icon, String tts}) _style() => switch (estado) {
    EstadoMesa.disponible => (
      bg: AppColors.success,
      fg: AppColors.textOnPrimary,
      icon: Icons.check_circle_outline,
      tts: 'Disponible',
    ),
    EstadoMesa.ocupada => (
      bg: AppColors.noDisp,
      fg: AppColors.textOnPrimary,
      icon: Icons.cancel_outlined,
      tts: 'Ocupada',
    ),
    EstadoMesa.reservada => (
      bg: AppColors.info,
      fg: AppColors.textOnPrimary,
      icon: Icons.event_available,
      tts: 'Reservada',
    ),
    EstadoMesa.pendiente => (
      bg: AppColors.surfacePending,
      fg: AppColors.textOnPrimary,
      icon: Icons.schedule,
      tts: 'Pendiente',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final s = _style();
    return Semantics(
      label: '${s.tts}, $label',
      child: Container(
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: s.bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, color: s.fg, size: iconSize),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: s.fg,
                fontWeight: FontWeight.w700,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
