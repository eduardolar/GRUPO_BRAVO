import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/colors_style.dart';

/// Toggle de dos segmentos (Comida / Cena) para elegir el turno de reserva.
class TurnoToggle extends StatelessWidget {
  const TurnoToggle({
    super.key,
    required this.turnoSeleccionado,
    required this.onCambiarTurno,
  });

  final String turnoSeleccionado;
  final ValueChanged<String> onCambiarTurno;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TurnoSegmento(
          turno: 'comida',
          label: 'Comida',
          horario: 'De 12:30 a 16:00',
          icono: Icons.wb_sunny_rounded,
          seleccionado: turnoSeleccionado == 'comida',
          onTap: () {
            HapticFeedback.selectionClick();
            onCambiarTurno('comida');
          },
        ),
        const SizedBox(width: 12),
        _TurnoSegmento(
          turno: 'cena',
          label: 'Cena',
          horario: 'De 20:00 a 23:30',
          icono: Icons.nightlight_round,
          seleccionado: turnoSeleccionado == 'cena',
          onTap: () {
            HapticFeedback.selectionClick();
            onCambiarTurno('cena');
          },
        ),
      ],
    );
  }
}

class _TurnoSegmento extends StatelessWidget {
  const _TurnoSegmento({
    required this.turno,
    required this.label,
    required this.horario,
    required this.icono,
    required this.seleccionado,
    required this.onTap,
  });

  final String turno;
  final String label;
  final String horario;
  final IconData icono;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sel = seleccionado;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.primaryAccent.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel
                  ? AppColors.primaryAccent
                  : Colors.white.withValues(alpha: 0.12),
              width: sel ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primaryAccent
                      : Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icono,
                  color: sel ? Colors.white : Colors.white60,
                  size: 16,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                horario,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: sel ? 0.7 : 0.45),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
