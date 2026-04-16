import 'package:flutter/material.dart';
import '../../core/colors_style.dart';

class TarjetaOpcionPago extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final bool seleccionada; // <-- Termina en 'a'
  final VoidCallback alPulsar;

  const TarjetaOpcionPago({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.seleccionada,
    required this.alPulsar,
  });

  @override
  Widget build(BuildContext context) {
    // Lógica visual para diferenciar marcas
    Color colorIcono = AppColors.button; // Color por defecto 
    if (seleccionada) { 
      if (titulo.contains('PayPal')) colorIcono = Colors.blue.shade800;
      if (titulo.contains('Google')) colorIcono = Colors.green.shade700;
    } 

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
                    ? colorIcono.withValues(alpha: 0.1) // Fondo suave del color de la marca
                    : AppColors.line.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icono,
                // Aplicamos el color especial para Google/PayPal
                color: seleccionada ? colorIcono : AppColors.iconPrimary, 
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