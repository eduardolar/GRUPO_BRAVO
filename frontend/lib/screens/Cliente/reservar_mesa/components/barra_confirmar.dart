import 'package:flutter/material.dart';

import '../../../../core/colors_style.dart';
import '../../../../components/Cliente/reservar_mesa/utils.dart' as ru;

/// Barra inferior sticky con el resumen de la reserva y el botón de confirmar.
class BarraConfirmar extends StatelessWidget {
  const BarraConfirmar({
    super.key,
    required this.fechaSeleccionada,
    required this.horaSeleccionada,
    required this.numComensales,
    required this.isLoading,
    required this.onConfirmar,
  });

  final DateTime fechaSeleccionada;
  final TimeOfDay horaSeleccionada;
  final int numComensales;
  final bool isLoading;
  final VoidCallback onConfirmar;

  @override
  Widget build(BuildContext context) {
    final diaTexto =
        '${ru.kDiasAbrev[fechaSeleccionada.weekday - 1]} '
        '${fechaSeleccionada.day} ${ru.kMesesAbrev[fechaSeleccionada.month - 1]}';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.6),
            Colors.black.withValues(alpha: 0.97),
          ],
          stops: const [0.0, 0.18, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _DatoResumen(
                    icono: Icons.calendar_today_rounded,
                    texto: diaTexto,
                  ),
                ),
                _Separador(),
                Expanded(
                  child: _DatoResumen(
                    icono: Icons.access_time_rounded,
                    texto: ru.formateoHora(horaSeleccionada),
                  ),
                ),
                _Separador(),
                Expanded(
                  child: _DatoResumen(
                    icono: Icons.people_rounded,
                    texto: '$numComensales',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onConfirmar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.button.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: isLoading
                  ? const SizedBox.shrink()
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'CONFIRMAR RESERVA',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DatoResumen extends StatelessWidget {
  const _DatoResumen({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icono, color: AppColors.button, size: 14),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texto,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _Separador extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}
