import 'package:flutter/material.dart';
import '../../../../core/colors_style.dart';
import 'entrega_constantes.dart';

class DireccionOption extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final bool seleccionada;
  final VoidCallback onTap;

  const DireccionOption({
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: kRadiusEntrega,
            color: seleccionada
                ? AppColors.primaryAccent.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: seleccionada
                  ? AppColors.primaryAccent
                  : Colors.white.withValues(alpha: 0.15),
              width: seleccionada ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icono,
                size: 18,
                color: seleccionada
                    ? AppColors.detailOnDark
                    : Colors.white.withValues(alpha: 0.50),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (seleccionada)
                const Icon(
                  Icons.check_circle,
                  size: 16,
                  color: AppColors.detailOnDark,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
