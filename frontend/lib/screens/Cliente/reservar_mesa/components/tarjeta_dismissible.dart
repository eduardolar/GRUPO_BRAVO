import 'package:flutter/material.dart';

import '../../../../core/colors_style.dart';
import '../../../../models/reserva_model.dart';
import 'tarjeta_reserva.dart';

/// Envuelve [TarjetaReserva] en un [Dismissible] de deslizamiento hacia la
/// izquierda para cancelar la reserva.
/// Si la reserva ya no es eliminable (fecha pasada), renderiza solo la tarjeta.
class TarjetaDismissible extends StatelessWidget {
  const TarjetaDismissible({
    super.key,
    required this.reserva,
    required this.pasada,
    required this.puedeEliminar,
    required this.puedeEditar,
    required this.onConfirmarEliminar,
    required this.onEditarComensales,
  });

  final Reserva reserva;
  final bool pasada;
  final bool puedeEliminar;
  final bool puedeEditar;
  final Future<bool> Function() onConfirmarEliminar;
  final VoidCallback onEditarComensales;

  @override
  Widget build(BuildContext context) {
    final tarjeta = TarjetaReserva(
      reserva: reserva,
      pasada: pasada,
      puedeEditar: puedeEditar,
      onEditarComensales: onEditarComensales,
    );

    if (!puedeEliminar) return tarjeta;

    return Dismissible(
      key: Key(reserva.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onConfirmarEliminar(),
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 26),
            SizedBox(height: 4),
            Text(
              'CANCELAR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: tarjeta,
    );
  }
}
