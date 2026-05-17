import 'package:flutter/material.dart';

import '../../../../core/colors_style.dart';

/// Pantalla de estado vacío cuando el usuario no tiene reservas.
class EstadoVacioReservas extends StatelessWidget {
  const EstadoVacioReservas({super.key, required this.onReservarAhora});

  final VoidCallback onReservarAhora;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: Colors.white24,
              size: 42,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Sin reservas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Playfair Display',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Haz tu primera reserva en unos segundos',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),
          TextButton(
            onPressed: onReservarAhora,
            child: const Text(
              'RESERVAR AHORA',
              style: TextStyle(
                color: AppColors.linkOnDark,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.linkOnDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
