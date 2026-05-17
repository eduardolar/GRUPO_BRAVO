import 'package:flutter/material.dart';

import '../../../../core/colors_style.dart';

/// Encabezado de sección con texto en mayúsculas, filete burdeos y separador.
class SeccionLabel extends StatelessWidget {
  const SeccionLabel(this.titulo, {super.key});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 5),
        Container(height: 2, width: 24, color: AppColors.detailOnDark),
        const SizedBox(height: 14),
      ],
    );
  }
}
