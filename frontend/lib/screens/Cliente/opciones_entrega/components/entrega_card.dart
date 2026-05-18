import 'package:flutter/material.dart';
import '../../../../core/colors_style.dart';
import 'entrega_constantes.dart';

class EntregaCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final String coste;
  final bool seleccionada;
  final VoidCallback onTap;

  const EntregaCard({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.coste,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: kRadiusEntrega,
            color: seleccionada
                ? AppColors.primaryAccent.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.07),
            border: Border.all(
              color: seleccionada
                  ? AppColors.primaryAccent
                  : Colors.white.withValues(alpha: 0.18),
              width: seleccionada ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: kAnimFast,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: seleccionada
                      ? AppColors.primaryAccent
                      : Colors.white.withValues(alpha: 0.10),
                ),
                child: Icon(
                  icono,
                  size: 22,
                  color: seleccionada
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.60),
                ),
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
                        fontSize: 15,
                        fontWeight:
                            seleccionada ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: kAnimFast,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: seleccionada
                      ? AppColors.primaryAccent
                      : Colors.white.withValues(alpha: 0.10),
                ),
                child: Text(
                  coste,
                  style: TextStyle(
                    color: seleccionada
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.60),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
