import 'package:flutter/material.dart';

import '../../../../core/colors_style.dart';

/// Botón circular usado en el diálogo de editar comensales.
class BotonDialogo extends StatelessWidget {
  const BotonDialogo({
    super.key,
    required this.icono,
    required this.onTap,
    required this.activo,
  });

  final IconData icono;
  final VoidCallback onTap;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: activo ? onTap : null,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activo
              ? AppColors.button.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: activo ? AppColors.button : AppColors.line,
          ),
        ),
        child: Icon(
          icono,
          color: activo ? AppColors.button : AppColors.line,
          size: 20,
        ),
      ),
    );
  }
}
