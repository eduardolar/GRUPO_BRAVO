import 'package:flutter/material.dart';

import '../../../core/colors_style.dart';
import '../../../models/reserva_model.dart';

/// Bottom sheet que se muestra tras confirmar una reserva. Resume todos
/// los datos y ofrece ir a "Mis reservas".
class ConfirmacionSheet extends StatelessWidget {
  final Reserva reserva;
  final String turno;
  final String fechaLarga;
  final VoidCallback onVerReservas;

  const ConfirmacionSheet({
    super.key,
    required this.reserva,
    required this.turno,
    required this.fechaLarga,
    required this.onVerReservas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.successBackground,
            ),
            child: const Icon(Icons.check, color: AppColors.disp, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            '¡Reserva Confirmada!',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Te esperamos en Bravo',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                _fila(Icons.calendar_today, fechaLarga),
                const Divider(color: AppColors.line, height: 16),
                _fila(
                  turno == 'comida'
                      ? Icons.wb_sunny_outlined
                      : Icons.nightlight_outlined,
                  turno == 'comida' ? 'Turno de comida' : 'Turno de cena',
                ),
                const Divider(color: AppColors.line, height: 16),
                _fila(Icons.access_time, reserva.hora),
                const Divider(color: AppColors.line, height: 16),
                _fila(Icons.people_outline, '${reserva.comensales} comensales'),
                const Divider(color: AppColors.line, height: 16),
                _fila(Icons.table_bar, 'Mesa ${reserva.numeroMesa ?? "-"}'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onVerReservas,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                elevation: 0,
              ),
              child: const Text(
                'VER MIS RESERVAS',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila(IconData icono, String texto) {
    return Row(
      children: [
        Icon(icono, color: AppColors.button, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
