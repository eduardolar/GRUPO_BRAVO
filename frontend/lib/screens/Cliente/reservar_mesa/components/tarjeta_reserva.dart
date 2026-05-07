import 'package:flutter/material.dart';

import '../../../../core/colors_style.dart';
import '../../../../models/reserva_model.dart';
import '../../../../components/Cliente/reservar_mesa/utils.dart' as ru;
import 'badge_small.dart';

/// Tarjeta visual de una reserva (próxima o pasada).
/// Si [puedeEditar] es true, muestra el botón de editar comensales.
class TarjetaReserva extends StatelessWidget {
  const TarjetaReserva({
    super.key,
    required this.reserva,
    required this.pasada,
    required this.puedeEditar,
    required this.onEditarComensales,
  });

  final Reserva reserva;
  final bool pasada;
  final bool puedeEditar;
  final VoidCallback onEditarComensales;

  static Color colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'confirmada':
        return AppColors.disp;
      case 'pendiente':
        return Colors.orange;
      case 'cancelada':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final esCena = reserva.turno == 'cena';
    final colorEst = colorEstado(reserva.estado);

    return Opacity(
      opacity: pasada ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.panel.withValues(alpha: pasada ? 0.8 : 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: pasada ? Colors.white10 : Colors.white24),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Columna fecha
              Container(
                width: 70,
                decoration: BoxDecoration(
                  color: pasada
                      ? AppColors.line.withValues(alpha: 0.5)
                      : AppColors.button.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${reserva.fecha.day}',
                      style: TextStyle(
                        color: pasada ? AppColors.textSecondary : AppColors.button,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    Text(
                      ru.kMesesAbrev[reserva.fecha.month - 1],
                      style: TextStyle(
                        color: pasada ? AppColors.textSecondary : AppColors.button,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ru.kDiasAbrev[reserva.fecha.weekday - 1],
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              // Detalles
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          BadgeSmall(
                            label: esCena ? 'Cena' : 'Comida',
                            icono: esCena
                                ? Icons.nightlight_outlined
                                : Icons.wb_sunny_outlined,
                            color: esCena ? Colors.indigo : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          BadgeSmall(
                            label: reserva.estado,
                            icono: Icons.circle,
                            color: colorEst,
                          ),
                          const Spacer(),
                          if (puedeEditar)
                            GestureDetector(
                              onTap: onEditarComensales,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.button.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.button
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.group_outlined,
                                  color: AppColors.button,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            reserva.hora,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.people_outline,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${reserva.comensales}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.table_bar,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Mesa ${reserva.numeroMesa ?? "-"}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      if (reserva.notas != null &&
                          reserva.notas!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.note_outlined,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                reserva.notas!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
