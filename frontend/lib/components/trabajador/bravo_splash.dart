import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/colors_style.dart';

const Duration _kSplashDuration = Duration(milliseconds: 2600);
const String _kBackgroundAsset = 'assets/images/Bravo restaurante.jpg';

/// Splash animado compartido entre todas las pantallas del trabajador.
///
/// Reproduce exactamente la misma animación que [InicioScreen]:
/// logo circular con fade+overshoot, título BRAVO con slide-up,
/// línea que se dibuja horizontalmente y subtítulo con letter-spacing animado.
///
/// Uso:
/// ```dart
/// BravoSplash(onFinished: () => setState(() => _appReady = true))
/// ```
class BravoSplash extends StatefulWidget {
  final VoidCallback onFinished;
  const BravoSplash({super.key, required this.onFinished});

  @override
  State<BravoSplash> createState() => _BravoSplashState();
}

class _BravoSplashState extends State<BravoSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleOffset;
  late final Animation<double> _lineProgress;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _subtitleSpacing;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _kSplashDuration);

    _logoOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOutBack),
      ),
    );
    _titleOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
    );
    _titleOffset = Tween<double>(begin: 14.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _lineProgress = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.45, 0.70, curve: Curves.easeOutCubic),
    );
    _subtitleOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
    );
    _subtitleSpacing = Tween<double>(begin: 12.0, end: 4.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.55, 0.90, curve: Curves.easeOutCubic),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted) return;
    await precacheImage(const AssetImage(_kBackgroundAsset), context);
    if (!mounted) return;
    await _ctrl.forward();
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _logoOpacity,
              child: ScaleTransition(
                scale: _logoScale,
                child: const _LogoCircular(size: 168),
              ),
            ),
            const SizedBox(height: 30),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, child) => Opacity(
                opacity: _titleOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _titleOffset.value),
                  child: child,
                ),
              ),
              child: Text(
                'BRAVO',
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.button,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _lineProgress,
              builder: (_, _) => Container(
                height: 1,
                width: 80 * _lineProgress.value,
                color: AppColors.button.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) => Opacity(
                opacity: _subtitleOpacity.value,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'EST. 2024  ·  ÁREA DE TRABAJO',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: _subtitleSpacing.value,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoCircular extends StatelessWidget {
  final double size;
  const _LogoCircular({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.sombra.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Image(
              image: AssetImage(_kBackgroundAsset),
              fit: BoxFit.cover,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.sombra.withValues(alpha: 0.25),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.button.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
