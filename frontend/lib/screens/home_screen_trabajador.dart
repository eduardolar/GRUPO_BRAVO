import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/app_routes.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/trabajador/Pedidos/gestion_pedidos.dart';
import 'package:frontend/screens/trabajador/Reservas/gestion_reservas.dart';
import 'package:frontend/screens/trabajador/Stock/gestion_stock.dart';
import 'package:frontend/screens/trabajador/appbar_trabajador.dart';
import 'package:frontend/screens/trabajador/servicio_trabajador/servicio.dart';

const Duration _kSplashDuration = Duration(milliseconds: 2600);
const Duration _kSwitchDuration = Duration(milliseconds: 850);
const BorderRadius _kRadius = BorderRadius.all(Radius.circular(12));
const double _kHeroMaxContentWidth = 500;
const String _kBackgroundAsset = 'assets/images/Bravo restaurante.jpg';

class HomeTrabajador extends StatefulWidget {
  const HomeTrabajador({super.key});

  @override
  State<HomeTrabajador> createState() => _HomeTrabajadorState();
}

class _HomeTrabajadorState extends State<HomeTrabajador> {
  bool _appReady = false;

  void _onSplashFinished() {
    if (!mounted) return;
    setState(() => _appReady = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: _kSwitchDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_appReady),
          child: _appReady
              ? const _ContenidoHome()
              : _Splash(onFinished: _onSplashFinished),
        ),
      ),
    );
  }
}

// ── SPLASH ───────────────────────────────────────────────────────────────

class _Splash extends StatefulWidget {
  final VoidCallback onFinished;
  const _Splash({required this.onFinished});

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
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
                child: _LogoCircular(asset: _kBackgroundAsset, size: 168),
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
  final String asset;
  final double size;
  const _LogoCircular({required this.asset, required this.size});

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
            Image(image: AssetImage(asset), fit: BoxFit.cover),
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

// ── CONTENIDO PRINCIPAL ──────────────────────────────────────────────────

class _ContenidoHome extends StatelessWidget {
  const _ContenidoHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: const TrabajadorAppBar(title: "RESTAURANTE BRAVO"),
      body: const SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(children: [_HeroSection(), _FooterQuote()]),
      ),
    );
  }
}

// ── HERO ─────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;
    final isWide = width > 600;
    final heroHeight = (height * (isWide ? 0.85 : 0.75)).clamp(540.0, 920.0);

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          width: width,
          height: heroHeight,
          child: const RepaintBoundary(
            child: Image(
              image: AssetImage(_kBackgroundAsset),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.3, 0.7, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.30),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                  AppColors.background,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _kHeroMaxContentWidth,
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BadgeGestion(),
                  SizedBox(height: 24),
                  Text(
                    'Panel de control\ndel trabajador.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      color: Colors.white,
                      fontSize: 38,
                      height: 1.1,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 15)],
                    ),
                  ),
                  SizedBox(height: 35),
                  _BotonesPrincipales(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeGestion extends StatelessWidget {
  const _BadgeGestion();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.button, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'GESTIÓN RESTAURANTE',
        style: TextStyle(
          color: AppColors.line,
          fontSize: 10,
          letterSpacing: 4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── BOTONES PRINCIPALES ──────────────────────────────────────────────────

class _BotonesPrincipales extends StatelessWidget {
  const _BotonesPrincipales();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BotonAccion(
          icon: Icons.event_available_outlined,
          label: 'Gestión de reservas',
          isPrimary: true,
          onPressed: () => Navigator.push(
            context,
            AppRoute.slide(const GestionReservas()),
          ),
        ),
        _BotonAccion(
          icon: Icons.receipt_long_outlined,
          label: 'Gestión de pedidos',
          onPressed: () => Navigator.push(
            context,
            AppRoute.slide(const GestionPedidos()),
          ),
        ),
        _BotonAccion(
          icon: Icons.room_service_outlined,
          label: 'Servicio',
          onPressed: () => Navigator.push(
            context,
            AppRoute.slide(const ServicioTrabajador()),
          ),
        ),
        _BotonAccion(
          icon: Icons.inventory_2_outlined,
          label: 'Gestión de stock',
          onPressed: () => Navigator.push(
            context,
            AppRoute.slide(const GestionStock()),
          ),
        ),
      ],
    );
  }
}

class _BotonAccion extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _BotonAccion({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final fondo = isPrimary
        ? AppColors.button
        : Colors.black.withValues(alpha: 0.25);

    final boton = Material(
      color: fondo,
      borderRadius: _kRadius,
      elevation: isPrimary ? 4 : 0,
      shadowColor: Colors.black54,
      child: InkWell(
        onTap: onPressed,
        borderRadius: _kRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: _kRadius,
            border: isPrimary ? null : Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.white54,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: isPrimary
          ? boton
          : ClipRRect(
              borderRadius: _kRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: boton,
              ),
            ),
    );
  }
}

// ── FOOTER ───────────────────────────────────────────────────────────────

class _FooterQuote extends StatelessWidget {
  const _FooterQuote();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          margin: const EdgeInsets.fromLTRB(24, 20, 24, 60),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: _kRadius,
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              Icon(
                Icons.format_quote,
                color: AppColors.button.withValues(alpha: 0.4),
                size: 30,
              ),
              const SizedBox(height: 16),
              const Text(
                'Excelencia en cada servicio.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
