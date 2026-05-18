import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/colors_style.dart';
import '../../../../models/restaurante_model.dart';
import '../../../../providers/restaurante_provider.dart';
import '../../../../components/Cliente/reservar_mesa/opcion_sucursal.dart';

/// Píldora informativa / selector de sucursal.
/// Si solo hay una sucursal activa, es meramente informativa.
/// Si hay varias, al pulsarla abre un bottom sheet para elegir.
class SelectorSucursalPill extends StatelessWidget {
  const SelectorSucursalPill({
    super.key,
    required this.restauranteSeleccionado,
    required this.onCambiarSucursal,
    required this.maxContentWidth,
  });

  final Restaurante? restauranteSeleccionado;
  final Future<void> Function(Restaurante) onCambiarSucursal;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return Consumer<RestauranteProvider>(
      builder: (_, prov, _) {
        final activas = prov.restaurantes.where((r) => r.activo).toList();
        if (prov.cargando && activas.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                color: AppColors.primaryOnDark,
                strokeWidth: 2,
              ),
            ),
          );
        }
        if (restauranteSeleccionado == null) return const SizedBox(height: 14);

        final clicable = activas.length > 1;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: clicable
                    ? () => _abrirSheet(context, activas)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.detailOnDark,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        restauranteSeleccionado!.nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      if (clicable) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirSheet(
    BuildContext context,
    List<Restaurante> activas,
  ) async {
    HapticFeedback.selectionClick();
    final elegida = await showModalBottomSheet<Restaurante>(
      context: context,
      backgroundColor: AppColors.panel,
      constraints: BoxConstraints(maxWidth: maxContentWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Elige restaurante',
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tu reserva se hará en el local que elijas',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...activas.map((r) {
                final activa = r.id == restauranteSeleccionado?.id;
                return OpcionSucursal(
                  restaurante: r,
                  activa: activa,
                  onTap: () => Navigator.pop(ctx, r),
                );
              }),
            ],
          ),
        ),
      ),
    );
    if (elegida != null) await onCambiarSucursal(elegida);
  }
}
