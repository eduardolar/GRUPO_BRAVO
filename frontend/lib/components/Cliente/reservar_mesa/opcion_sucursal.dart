import 'package:flutter/material.dart';

import '../../../core/colors_style.dart';
import '../../../models/restaurante_model.dart';

/// Fila de un restaurante dentro del bottom sheet de selección de sucursal.
/// La opción activa lleva un acento burdeos y un check; las demás se ven
/// como opciones secundarias para no robar atención.
class OpcionSucursal extends StatelessWidget {
  final Restaurante restaurante;
  final bool activa;
  final VoidCallback onTap;

  const OpcionSucursal({
    super.key,
    required this.restaurante,
    required this.activa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = restaurante;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: activa
                  ? AppColors.button.withValues(alpha: 0.08)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: activa
                    ? AppColors.button.withValues(alpha: 0.6)
                    : AppColors.line,
                width: activa ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activa
                        ? AppColors.button.withValues(alpha: 0.18)
                        : AppColors.panel,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: activa
                          ? AppColors.button.withValues(alpha: 0.4)
                          : AppColors.line,
                    ),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: activa ? AppColors.button : AppColors.textSecondary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.nombre.isEmpty ? '(sin nombre)' : r.nombre,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: activa
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                      if (r.direccion.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          r.direccion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (activa)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.button,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
