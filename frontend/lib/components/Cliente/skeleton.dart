import 'package:flutter/material.dart';
import '../../core/colors_style.dart';

/// Bloque de skeleton animado reutilizable.
///
/// Gestiona su propio [AnimationController] para no requerir un ticker
/// en el widget padre. Dos variantes de color:
///   - light (por defecto) — gradiente horizontal sobre [AppColors.line]
///   - dark               — pulso de opacidad blanca, para fondos oscuros
class SkeletonBlock extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool dark;

  const SkeletonBlock({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius = 6,
    this.dark = false,
  });

  /// Variante oscura (fondos de imagen / negro)
  const SkeletonBlock.dark({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius = 6,
  }) : dark = true;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: widget.dark);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final v = _ctrl.value;
        final decoration = widget.dark
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                color: Color.lerp(
                  Colors.white.withValues(alpha: 0.05),
                  AppColors.button.withValues(alpha: 0.20),
                  Curves.easeInOut.transform(v),
                ),
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                gradient: LinearGradient(
                  colors: [
                    AppColors.line.withValues(alpha: 0.4),
                    AppColors.line.withValues(alpha: 0.85),
                    AppColors.line.withValues(alpha: 0.4),
                  ],
                  stops: [
                    (v - 0.35).clamp(0.0, 1.0),
                    v.clamp(0.0, 1.0),
                    (v + 0.35).clamp(0.0, 1.0),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              );

        return Container(
          width: widget.width == double.infinity ? null : widget.width,
          height: widget.height,
          decoration: decoration,
        );
      },
    );
  }
}
