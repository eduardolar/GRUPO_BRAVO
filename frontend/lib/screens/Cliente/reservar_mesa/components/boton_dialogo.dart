import 'package:flutter/material.dart';

import '../../../../core/colors_style.dart';

/// Botón circular usado en el diálogo de editar comensales.
class BotonDialogo extends StatelessWidget {
  const BotonDialogo({
    super.key,
    required this.icono,
    required this.onTap,
    required this.activo,
    this.label,
  });

  final IconData icono;
  final VoidCallback onTap;
  final bool activo;
  /// Etiqueta semántica para lectores de pantalla.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = label ??
        (icono == Icons.add ? 'Añadir comensal' : 'Quitar comensal');
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: activo,
      child: GestureDetector(
        onTap: activo ? onTap : null,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activo
                ? AppColors.detailOnDark.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border.all(
              color: activo ? AppColors.detailOnDark : AppColors.line,
            ),
          ),
          child: Icon(
            icono,
            color: activo ? AppColors.detailOnDark : AppColors.line,
            size: 20,
          ),
        ),
      ),
    );
  }
}
