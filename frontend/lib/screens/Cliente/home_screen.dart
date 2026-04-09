import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frontend/components/Cliente/codigo_qr.dart';
import 'package:frontend/components/Cliente/domicilio_button.dart';
import 'package:frontend/components/Cliente/reservar_mesa.dart';
import 'package:frontend/screens/Cliente/login_screen.dart';

// ─── Paleta 60-30-10 ───────────────────────────────────────────────
// 60% → negro cálido profundo:  AppColors.background
// 30% → marrón oscuro cálido:   AppColors.backgroundButton
// 10% → dorado:                 AppColors.gold
// ───────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _headerIconKey = GlobalKey();

  // ── Logo splash ──
  late AnimationController _logoAnim;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoFadeOut;
  bool _logoDone = false;

  // ── Plato/campana splash ──
  late AnimationController _anim;
  // Fase 1: plato aparece
  late Animation<double> _plateOpacity;
  late Animation<double> _plateScale;
  // Fase 2: campana baja
  late Animation<double> _clocheY;
  late Animation<double> _clocheOpacity;
  // Fase 3: vapor sube
  late Animation<double> _steamOpacity;
  late Animation<double> _steamDrift;
  // Fase 4: todo se funde en icono y se mueve al header
  late Animation<double> _morphProgress;
  late Animation<double> _moveProgress;
  late Animation<double> _overlayOpacity;
  late Animation<double> _contentOpacity;
  bool _animDone = false;

  late final List<_SmokeParticle> _particles;

  @override
  void initState() {
    super.initState();

    final rng = Random(42);
    _particles = List.generate(35, (i) {
      return _SmokeParticle(
        angle: -pi / 2 + (rng.nextDouble() - 0.5) * pi * 0.8,
        radius: 50 + rng.nextDouble() * 120,
        driftY: 80 + rng.nextDouble() * 200,
        size: 16 + rng.nextDouble() * 36,
        delay: rng.nextDouble() * 0.3,
        opacity: 0.15 + rng.nextDouble() * 0.35,
      );
    });

    // ── Logo animation (2.5s): fade in + scale → hold → fade out ──
    _logoAnim =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2500),
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed) {
            setState(() => _logoDone = true);
            _anim.forward();
          }
        });

    _logoOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 25),
    ]).animate(_logoAnim);

    _logoScale = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnim,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    _logoFadeOut = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoAnim,
        curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
      ),
    );

    // ── Plato/campana animation (4s) ──
    _anim =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 4000),
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed) setState(() => _animDone = true);
        });

    // 0.00–0.12 plato aparece
    _plateOpacity = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _anim, curve: const Interval(0.0, 0.08)));
    _plateScale = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _anim,
        curve: const Interval(0.0, 0.12, curve: Curves.easeOutBack),
      ),
    );

    // 0.10–0.28 campana baja desde arriba
    _clocheOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: const Interval(0.10, 0.16)),
    );
    _clocheY = Tween(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _anim,
        curve: const Interval(0.10, 0.28, curve: Curves.bounceOut),
      ),
    );

    // 0.28–0.60 vapor
    _steamOpacity =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 45),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 35),
        ]).animate(
          CurvedAnimation(parent: _anim, curve: const Interval(0.28, 0.62)),
        );
    _steamDrift = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _anim,
        curve: const Interval(0.28, 0.62, curve: Curves.easeOut),
      ),
    );

    // 0.58–0.72 plato+campana se funden en icono circular
    _morphProgress = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _anim,
        curve: const Interval(0.58, 0.72, curve: Curves.easeInOutCubic),
      ),
    );

    // 0.70–0.90 icono se mueve a su posición
    _moveProgress = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _anim,
        curve: const Interval(0.72, 0.92, curve: Curves.easeInOutCubic),
      ),
    );

    // 0.90–1.0 overlay desaparece
    _overlayOpacity = Tween(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _anim, curve: const Interval(0.90, 1.0)));
    _contentOpacity = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _anim, curve: const Interval(0.85, 1.0)));

    _logoAnim.forward();
  }

  @override
  void dispose() {
    _logoAnim.dispose();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F6),
      body: SafeArea(
        child: _animDone
            ? _buildHomeContent()
            : !_logoDone
            ? AnimatedBuilder(
                animation: _logoAnim,
                builder: (context, _) => _buildLogoSplash(),
              )
            : AnimatedBuilder(
                animation: _anim,
                builder: (context, _) => Stack(
                  children: [
                    Opacity(
                      opacity: _contentOpacity.value,
                      child: _buildHomeContent(),
                    ),
                    _buildSplashOverlay(),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Logo splash: muestra el logo del restaurante ──────────────
  Widget _buildLogoSplash() {
    return Container(
      color: const Color(0xFFFBF9F6),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Opacity(
          opacity: _logoFadeOut.value,
          child: Opacity(
            opacity: _logoOpacity.value,
            child: Transform.scale(
              scale: _logoScale.value,
              child: Image.asset(
                'assets/images/Bravo restaurante.jpg',
                width: 260,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "SELECCIONA UNA OPCIÓN:",
                  style: TextStyle(
                    color: Color(0xFF800020),
                    fontSize: 10,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                const CodigoQr(),
                const SizedBox(height: 40),
                const DomicilioButton(),
                const SizedBox(height: 40),
                const ReservarMesa(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Overlay splash: plato → campana → vapor → transición ───────
  Widget _buildSplashOverlay() {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final morph = _morphProgress.value;
    final move = _moveProgress.value;

    // Centro del plato/campana en pantalla
    const dishW = 140.0;
    final centerX = screenW / 2;
    final centerY = screenH / 2 - 20;

    // Posición final del icono en header
    double endX = centerX - 20;
    double endY = 24.0;
    const endSize = 40.0;
    final keyCtx = _headerIconKey.currentContext;
    if (keyCtx != null) {
      final box = keyCtx.findRenderObject() as RenderBox;
      final pos = box.localToGlobal(Offset.zero);
      final safePad = MediaQuery.of(context).padding.top;
      endX = pos.dx;
      endY = pos.dy - safePad;
    }

    // Interpolar posición durante morph+move
    final combinedMove = (morph * 0.3 + move * 0.7).clamp(0.0, 1.0);
    final curSize = lerpDouble(dishW, endSize, combinedMove)!;
    final curCenterX = lerpDouble(centerX, endX + endSize / 2, combinedMove)!;
    final curCenterY = lerpDouble(centerY, endY + endSize / 2, combinedMove)!;

    // Opacidad plato+campana se desvanecen mientras aparece icono circular
    final dishOpacity = (1.0 - morph).clamp(0.0, 1.0);
    final iconOpacity = morph;

    return IgnorePointer(
      child: Opacity(
        opacity: _overlayOpacity.value,
        child: Container(
          color: const Color(0xFFFBF9F6),
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              // ── Partículas de vapor ──
              ..._particles.map((p) {
                final d = (_steamDrift.value - p.delay).clamp(0.0, 1.0);
                final dx = cos(p.angle) * p.radius * d;
                final dy = -p.driftY * d;
                final pOp = _steamOpacity.value * p.opacity * (1.0 - d * 0.8);
                return Positioned(
                  left: centerX - p.size / 2 + dx,
                  top: centerY - p.size / 2 + dy,
                  child: Opacity(
                    opacity: pOp.clamp(0.0, 1.0),
                    child: Container(
                      width: p.size,
                      height: p.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.18),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // ── Ondas sinuosas de vapor ──
              ...List.generate(5, (i) {
                final wDelay = i * 0.06;
                final d = (_steamDrift.value - wDelay).clamp(0.0, 1.0);
                final wOp = _steamOpacity.value * 0.5 * (1.0 - d);
                final wy = -100.0 * d - i * 22;
                final wx = sin(d * pi * 2.5 + i * 1.3) * 20;
                return Positioned(
                  left: centerX - 10 + wx,
                  top: centerY + wy,
                  child: Opacity(
                    opacity: d > 0 ? wOp.clamp(0.0, 1.0) : 0.0,
                    child: Text(
                      '∿',
                      style: TextStyle(
                        fontSize: 28 - i * 3,
                        color: Colors.white.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w200,
                      ),
                    ),
                  ),
                );
              }),

              // ── Plato (elipse) ──
              Positioned(
                left: curCenterX - curSize / 2,
                top: curCenterY - curSize * 0.15,
                child: Opacity(
                  opacity: _plateOpacity.value * dishOpacity,
                  child: Transform.scale(
                    scale: _plateScale.value,
                    child: CustomPaint(
                      size: Size(curSize, curSize * 0.3),
                      painter: _PlatePainter(const Color(0xFF1A1A1A)),
                    ),
                  ),
                ),
              ),

              // ── Campana (domo) ──
              Positioned(
                left: curCenterX - curSize / 2,
                top:
                    curCenterY -
                    curSize * 0.55 +
                    _clocheY.value * curSize * 0.6,
                child: Opacity(
                  opacity: _clocheOpacity.value * dishOpacity,
                  child: CustomPaint(
                    size: Size(curSize, curSize * 0.55),
                    painter: _ClochePainter(const Color(0xFF1A1A1A)),
                  ),
                ),
              ),

              // ── Icono circular (aparece con morph) ──
              Positioned(
                left: curCenterX - curSize / 2,
                top: curCenterY - curSize / 2,
                child: Opacity(
                  opacity: iconOpacity,
                  child: Container(
                    width: curSize,
                    height: curSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1A1A1A),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.room_service_outlined,
                      color: const Color(0xFF1A1A1A),
                      size: curSize * 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF800020),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Icono de login arriba a la izquierda
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              // Logo y nombre centrados
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: _animDone ? 1.0 : 0.0,
                    child: Container(
                      key: _headerIconKey,
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.room_service_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Tu Restaurante",
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      color: Color(0xFFFFF8E1),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "BIENVENIDO",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 10,
              letterSpacing: 3,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.2)),
              ),
              Container(
                width: 60,
                height: 1.5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Modelo de partícula de humo ─────────────────────────────────
class _SmokeParticle {
  final double angle;
  final double radius;
  final double driftY;
  final double size;
  final double delay;
  final double opacity;

  const _SmokeParticle({
    required this.angle,
    required this.radius,
    required this.driftY,
    required this.size,
    required this.delay,
    required this.opacity,
  });
}

// ── Painter: plato (elipse dorada) ──────────────────────────────
class _PlatePainter extends CustomPainter {
  final Color color;
  _PlatePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.5)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawOval(rect, paint);

    // Borde
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Painter: campana / cloche ───────────────────────────────────
class _ClochePainter extends CustomPainter {
  final Color color;
  _ClochePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    // Arco del domo
    path.moveTo(0, size.height);
    path.quadraticBezierTo(
      size.width * 0.5,
      -size.height * 0.6, // pico del domo
      size.width,
      size.height,
    );
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.6)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);

    // Borde
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);

    // Asa (bolita arriba)
    final handlePaint = Paint()..color = color;
    canvas.drawCircle(Offset(size.width / 2, 4), 5, handlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
