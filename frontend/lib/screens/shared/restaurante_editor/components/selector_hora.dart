import 'package:flutter/material.dart';
import '../../../../core/colors_style.dart';

/// Botón compacto que muestra una hora y abre el selector al pulsarlo.
/// Compartido entre [SuperLocalEditarScreen] y [AdminLocalEditarScreen].
class SelectorHora extends StatelessWidget {
  final String hora;
  final String tooltip;
  final VoidCallback onTap;

  const SelectorHora({
    super.key,
    required this.hora,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time, color: AppColors.button, size: 14),
              const SizedBox(width: 4),
              Text(
                hora,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
