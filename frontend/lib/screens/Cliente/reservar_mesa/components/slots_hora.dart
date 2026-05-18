import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/colors_style.dart';
import '../../../../components/Cliente/reservar_mesa/utils.dart' as ru;

/// Grid de slots de hora disponibles / completos.
/// Pasa el callback [onHoraSeleccionada] cuando el usuario elige una hora libre.
class SlotsHora extends StatelessWidget {
  const SlotsHora({
    super.key,
    required this.cargandoDisponibilidad,
    required this.slotsFiltrados,
    required this.disponibilidadHoras,
    required this.horaSeleccionada,
    required this.onHoraSeleccionada,
  });

  final bool cargandoDisponibilidad;
  final List<TimeOfDay> slotsFiltrados;
  final Map<String, bool> disponibilidadHoras;
  final TimeOfDay horaSeleccionada;
  final ValueChanged<TimeOfDay> onHoraSeleccionada;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        const columns = 4;
        final slotWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final fontSize = (slotWidth * 0.2).clamp(11.0, 15.0);

        if (cargandoDisponibilidad) {
          return const SizedBox(
            height: 54,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.primaryOnDark,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          );
        }

        if (slotsFiltrados.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  color: Colors.white38,
                  size: 16,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No hay horarios disponibles para este turno',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: slotsFiltrados.map((hora) {
            final horaStr = ru.formateoHora(hora);
            final disponible = disponibilidadHoras[horaStr] ?? true;
            final sel = hora == horaSeleccionada && disponible;
            return GestureDetector(
              onTap: disponible
                  ? () {
                      HapticFeedback.selectionClick();
                      onHoraSeleccionada(hora);
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: slotWidth,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primaryAccent
                      : disponible
                      ? AppColors.panel.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel
                        ? AppColors.primaryAccent
                        : disponible
                        ? Colors.white24
                        : Colors.white10,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      horaStr,
                      style: TextStyle(
                        color: sel
                            ? Colors.white
                            : disponible
                            ? AppColors.textPrimary
                            : Colors.white24,
                        fontWeight: FontWeight.bold,
                        fontSize: fontSize + 2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      disponible ? (sel ? '✓ Elegida' : 'Libre') : 'Completo',
                      style: TextStyle(
                        color: sel
                            ? Colors.white70
                            : disponible
                            ? AppColors.disp
                            : AppColors.error,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
