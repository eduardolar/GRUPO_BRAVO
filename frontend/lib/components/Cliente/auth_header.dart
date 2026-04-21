import 'package:flutter/material.dart';
import '../../core/colors_style.dart';

/// Cabecera estándar para pantallas de autenticación.
/// Muestra título en Playfair Display, línea decorativa y subtítulo.
class AuthHeader extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget? subtituloWidget;

  const AuthHeader({
    super.key,
    required this.titulo,
    this.subtitulo = '',
    this.subtituloWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Playfair Display',
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Container(height: 2, width: 40, color: AppColors.button),
        const SizedBox(height: 15),
        if (subtituloWidget != null)
          subtituloWidget!
        else
          Text(
            subtitulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 15,
            ),
          ),
      ],
    );
  }
}
