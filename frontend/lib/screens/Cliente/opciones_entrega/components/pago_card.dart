import 'package:flutter/material.dart';
import '../../../../core/colors_style.dart';
import 'entrega_constantes.dart';

class PagoCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final bool seleccionada;
  final VoidCallback onTap;

  const PagoCard({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: kRadiusEntrega,
        child: AnimatedContainer(
          duration: kAnimFast,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: kRadiusEntrega,
            color: seleccionada
                ? AppColors.button.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.07),
            border: Border.all(
              color: seleccionada
                  ? AppColors.button
                  : Colors.white.withValues(alpha: 0.18),
              width: seleccionada ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icono,
                size: 24,
                color: seleccionada
                    ? AppColors.button
                    : Colors.white.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight:
                            seleccionada ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: kAnimFast,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: seleccionada ? AppColors.button : Colors.transparent,
                  border: Border.all(
                    color: seleccionada
                        ? AppColors.button
                        : Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: seleccionada
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
