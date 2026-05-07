import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/colors_style.dart';
import '../../../../components/Cliente/reservar_mesa/utils.dart' as ru;

/// Strip horizontal de chips de fecha (hoy + 60 días).
class FechaStrip extends StatelessWidget {
  const FechaStrip({
    super.key,
    required this.fechas,
    required this.fechaSeleccionada,
    required this.scrollController,
    required this.onFechaSeleccionada,
  });

  static const double kItemWidth = 64.0;

  final List<DateTime> fechas;
  final DateTime fechaSeleccionada;
  final ScrollController scrollController;
  final ValueChanged<DateTime> onFechaSeleccionada;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: fechas.length,
        itemBuilder: (_, i) => _DateChip(
          fecha: fechas[i],
          seleccionada: ru.mismaFecha(fechas[i], fechaSeleccionada),
          onTap: () => onFechaSeleccionada(fechas[i]),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.fecha,
    required this.seleccionada,
    required this.onTap,
  });

  final DateTime fecha;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hoy = ru.esHoy(fecha);
    final esFinDeSemana = fecha.weekday >= 6;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: FechaStrip.kItemWidth - 4,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: seleccionada
              ? AppColors.button
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionada
                ? AppColors.button
                : Colors.white.withValues(alpha: 0.12),
            width: seleccionada ? 1.4 : 1,
          ),
          boxShadow: seleccionada
              ? [
                  BoxShadow(
                    color: AppColors.button.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hoy ? 'HOY' : ru.kDiasAbrev[fecha.weekday - 1],
              style: TextStyle(
                color: seleccionada
                    ? Colors.white
                    : (esFinDeSemana
                          ? AppColors.button.withValues(alpha: 0.9)
                          : Colors.white60),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${fecha.day}',
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ru.kMesesAbrev[fecha.month - 1],
              style: TextStyle(
                color: seleccionada
                    ? Colors.white.withValues(alpha: 0.85)
                    : Colors.white54,
                fontSize: 9,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
