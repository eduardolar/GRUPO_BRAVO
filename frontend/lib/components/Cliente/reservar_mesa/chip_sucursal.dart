import 'package:flutter/material.dart';

import '../../../core/colors_style.dart';
import '../../../models/restaurante_model.dart';

/// Chip horizontal del selector de sucursales del cliente al reservar.
class ChipSucursalCliente extends StatelessWidget {
  final Restaurante restaurante;
  final bool activa;
  final VoidCallback onTap;

  const ChipSucursalCliente({
    super.key,
    required this.restaurante,
    required this.activa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: activa
                ? AppColors.button.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activa
                  ? AppColors.button
                  : Colors.white.withValues(alpha: 0.18),
              width: activa ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                activa ? Icons.storefront_rounded : Icons.storefront_outlined,
                size: 14,
                color: activa ? AppColors.button : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                restaurante.nombre.isEmpty
                    ? '(sin nombre)'
                    : restaurante.nombre,
                style: TextStyle(
                  color: activa ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
