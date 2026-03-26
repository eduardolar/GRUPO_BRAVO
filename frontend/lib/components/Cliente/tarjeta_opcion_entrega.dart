import 'package:flutter/material.dart';
import '../../core/colors_style.dart';

class TarjetaOpcionEntrega extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final bool seleccionada;
  final String coste;
  final VoidCallback alPulsar;

  const TarjetaOpcionEntrega({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.seleccionada,
    required this.coste,
    required this.alPulsar,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alPulsar,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: seleccionada ? AppColors.panel : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionada ? AppColors.button : AppColors.line,
            width: seleccionada ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: seleccionada
                    ? AppColors.button.withValues(alpha: 0.1)
                    : AppColors.line.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icono,
                color: seleccionada ? AppColors.button : AppColors.iconPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: seleccionada
                    ? AppColors.button
                    : AppColors.line.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                coste,
                style: TextStyle(
                  color: seleccionada
                      ? AppColors.background
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              seleccionada
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: seleccionada ? AppColors.button : AppColors.line,
            ),
          ],
        ),
      ),
    );
  }
}
