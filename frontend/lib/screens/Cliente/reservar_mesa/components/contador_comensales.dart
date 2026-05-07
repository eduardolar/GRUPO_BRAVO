import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/colors_style.dart';

/// Contador de comensales con botones +/- y número animado.
class ContadorComensales extends StatelessWidget {
  const ContadorComensales({
    super.key,
    required this.numComensales,
    required this.maxComensales,
    required this.onCambiar,
  });

  final int numComensales;
  final int maxComensales;
  final ValueChanged<int> onCambiar;

  @override
  Widget build(BuildContext context) {
    final puedeRestar = numComensales > 1;
    final puedeSumar = numComensales < maxComensales;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _BotonComensales(
            icono: Icons.remove_rounded,
            onTap: () => onCambiar(-1),
            activo: puedeRestar,
          ),
          Expanded(
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: Text(
                    '$numComensales',
                    key: ValueKey(numComensales),
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  numComensales == 1
                      ? 'persona'
                      : '$numComensales personas'.split(' ').last,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _BotonComensales(
            icono: Icons.add_rounded,
            onTap: () => onCambiar(1),
            activo: puedeSumar,
          ),
        ],
      ),
    );
  }
}

class _BotonComensales extends StatelessWidget {
  const _BotonComensales({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activo
              ? AppColors.button
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: activo
                ? AppColors.button
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Icon(
          icono,
          color: activo ? Colors.white : Colors.white24,
          size: 22,
        ),
      ),
    );
  }
}
