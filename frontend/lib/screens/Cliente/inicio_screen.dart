import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/components/bravo_app_bar.dart';
import 'package:frontend/core/app_routes.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/core/url_helper.dart';
import 'package:frontend/models/destino_login.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/screens/cliente/carta_screen.dart';
import 'package:frontend/screens/cliente/login_screen.dart';
import 'package:frontend/screens/cliente/pedido_confirmado_screen.dart';
import 'package:frontend/screens/cliente/reservar_mesa_screen.dart';
import 'package:frontend/screens/cliente/scanner_qr.dart';
import 'package:frontend/screens/cliente/seleccionar_restaurante_screen.dart';
import 'package:frontend/services/api_service.dart';

// Duración del splash inicial (animación del logo BRAVO antes de mostrar la app).
const Duration _kSplashDuration = Duration(milliseconds: 2600);
// Duración del fade entre splash y contenido principal.
const Duration _kSwitchDuration = Duration(milliseconds: 850);
const BorderRadius _kRadius = BorderRadius.all(Radius.circular(12));
const double _kHeroMaxContentWidth = 500;
const String _kBackgroundAsset = 'assets/images/Bravo restaurante.jpg';

/// Pantalla raíz de la app de cliente.
///
/// Responsable de:
/// 1. Mostrar el splash animado al arrancar.
/// 2. Capturar el redirect de Stripe (solo web) cuando el cliente vuelve
///    desde la página de pago externo, verificar que el pago fue confirmado
///    y abrir [PedidoConfirmadoScreen].
/// 3. Mostrar el hero con los tres CTA principales del cliente: escanear QR
///    de mesa, pedido a domicilio y reservar mesa.
class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  // `true` cuando el splash terminó y se muestra el contenido principal.
  bool _appReady = false;

  // Datos del redirect de Stripe (solo web). `_stripeSessionId` viene como
  // query param `?stripe_session=...` cuando Stripe Checkout redirige de vuelta
  // a la app tras un pago exitoso.
  String? _stripeSessionId;
  String _stripeEntrega = '';
  double _stripeTotal = 0;

  @override
  void initState() {
    super.initState();
    _capturarRedirectStripe();
  }

  /// Lee los query params del navegador para detectar si venimos de Stripe.
  /// En móvil/desktop no aplica: el flujo de pago vuelve por callback nativo.
  void _capturarRedirectStripe() {
    if (!kIsWeb) return;
    final params = Uri.base.queryParameters;
    final sessionId = params['stripe_session'];
    if (sessionId == null || sessionId.isEmpty) return;
    _stripeSessionId = sessionId;
    _stripeEntrega = Uri.decodeQueryComponent(params['entrega'] ?? 'Tu pedido');
    _stripeTotal = double.tryParse(params['total'] ?? '0') ?? 0;
    // Limpiamos la URL del navegador (`?stripe_session=…`) en cuanto la
    // hemos leído. Sin esto, cada F5 / re-entrada al inicio_screen vuelve
    // a parsear la sesión y vuelve a abrir PedidoConfirmadoScreen, aunque
    // el cliente no haya hecho ningún pedido nuevo.
    limpiarQueryParams();
  }

  void _onSplashFinished() {
    if (!mounted) return;
    setState(() => _appReady = true);
    if (_stripeSessionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _verificarStripeRedirect();
      });
    }
  }

  /// Verifica contra el backend que la sesión de Stripe que viene en el URL
  /// fue realmente pagada. Si lo fue, marca el pedido como pagado en nuestra
  /// BBDD y abre la pantalla de confirmación. Si falla la verificación, muestra
  /// snackbar de error en lugar de avanzar — protege contra URLs manipuladas.
  Future<void> _verificarStripeRedirect() async {
    final sessionId = _stripeSessionId!;
    _stripeSessionId = null;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pagado = await ApiService.verificarCheckoutSession(
        sessionId: sessionId,
      );
      if (!mounted || !pagado) return;
      await ApiService.actualizarEstadoPago(referenciaPago: sessionId);
      if (!mounted) return;
      navigator.push(
        AppRoute.reveal(
          PedidoConfirmadoScreen(
            tipoEntrega: _stripeEntrega,
            tipoPago: 'Tarjeta',
            total: _stripeTotal,
            pedidoId: sessionId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error verificando Stripe: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'No pudimos verificar el pago. Inténtalo de nuevo.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: _kRadius),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
    }
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
              ? const _ContenidoInicio()
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

    // Logo: fade + slight overshoot scale (0% → 30%)
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

    // Title BRAVO: fade + slide up (25% → 55%)
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

    // Line: draws horizontally (45% → 70%)
    _lineProgress = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.45, 0.70, curve: Curves.easeOutCubic),
    );

    // Subtitle: fade + letter-spacing settle (55% → 85%)
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
    // Cargar la imagen antes de animar para evitar parpadeo del logo.
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
                // FittedBox con scaleDown protege contra desbordamiento
                // horizontal cuando el SO usa "tamaño de texto grande" o
                // cuando la pantalla es muy estrecha: el `letterSpacing`
                // animado va hasta 12, y a fontSize 10 puede pasarse del ancho
                // disponible. scaleDown solo actúa si hace falta, por lo que
                // el caso normal queda intacto.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'EST. 2024  ·  RESTAURANTE',
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

class _ContenidoInicio extends StatelessWidget {
  const _ContenidoInicio();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final tituloRestaurante =
        cart.restauranteNombre?.toUpperCase() ?? 'RESTAURANTE BRAVO';
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: BravoAppBar(title: tituloRestaurante, isRoot: true),
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
                  _BadgeAnio(),
                  SizedBox(height: 24),
                  Text(
                    'Hecho con tradición,\nservido con pasión.',
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

class _BadgeAnio extends StatelessWidget {
  const _BadgeAnio();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.button, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'EST. 2024',
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

/// Tres CTAs principales del cliente: escanear QR, domicilio y reservar.
///
/// Para los flujos que requieren autenticación (carta y reserva), si el
/// usuario no está logueado se le redirige al login con el destino guardado,
/// para volver al flujo correcto tras autenticarse.
class _BotonesPrincipales extends StatelessWidget {
  const _BotonesPrincipales();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();

    return Column(
      children: [
        _BotonAccion(
          icon: Icons.qr_code_scanner,
          label: cart.tienemesa
              ? 'Mesa ${cart.numeroMesa} · Cambiar'
              : 'Escanear QR de mesa',
          isPrimary: true,
          onPressed: () => _escanearQr(context),
        ),
        _BotonAccion(
          icon: Icons.motorcycle,
          label: 'Pedido a domicilio',
          onPressed: () => _abrirCarta(context, auth, cart),
        ),
        _BotonAccion(
          icon: Icons.calendar_month,
          label: 'Reservar mesa',
          onPressed: () => _abrirReserva(context, auth, cart),
        ),
      ],
    );
  }

  void _abrirCarta(BuildContext context, AuthProvider auth, CartProvider cart) {
    if (!auth.estaAutenticado) {
      Navigator.push(context, AppRoute.slide(const LoginScreen()));
      return;
    }
    Navigator.push(
      context,
      cart.restauranteId != null
          ? AppRoute.slide(const CartaScreen())
          : AppRoute.slide(
              const SeleccionarRestauranteScreen(siguiente: CartaScreen()),
            ),
    );
  }

  void _abrirReserva(
    BuildContext context,
    AuthProvider auth,
    CartProvider cart,
  ) {
    if (!auth.estaAutenticado) {
      Navigator.push(
        context,
        AppRoute.slide(const LoginScreen(destino: DestinoLogin.reservar)),
      );
      return;
    }
    Navigator.push(
      context,
      cart.restauranteId != null
          ? AppRoute.slide(const ReservarMesaScreen())
          : AppRoute.slide(
              const SeleccionarRestauranteScreen(
                siguiente: ReservarMesaScreen(),
              ),
            ),
    );
  }

  /// Abre el escáner QR y, con el código leído, valida contra el backend que
  /// sea un QR de mesa válido. Solo si el backend lo autoriza guardamos la
  /// mesa en el carrito — esto evita que un QR pegado falsamente o de otro
  /// restaurante asigne mesa al cliente.
  Future<void> _escanearQr(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final codigoQr = await navigator.push<String>(
      AppRoute.slideUp(const QRScanner()),
    );
    if (codigoQr == null) return;

    try {
      final resultado = await ApiService.validarQrMesa(codigoQr: codigoQr);
      final mesaId = resultado['mesa_id'] as String;
      final numMesa = int.tryParse(resultado['numero_mesa'].toString()) ?? 0;

      cart.asignarMesa(mesaId: mesaId, numeroMesa: numMesa);
      if (!context.mounted) return;

      final auth = context.read<AuthProvider>();
      navigator.push(
        auth.estaAutenticado
            ? AppRoute.slide(const CartaScreen())
            : AppRoute.slideUp(const LoginScreen(destino: DestinoLogin.menu)),
      );
    } catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('Error al validar el QR: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(borderRadius: _kRadius),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          ),
        );
    }
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
    // Para botones secundarios bajamos el alpha del fondo (0.25 vs 0.55) para
    // que el blur del BackdropFilter sea visible. Si dejásemos 0.55, el negro
    // semi-opaco taparía el efecto cristal y el blur no se notaría.
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

    // Solo aplicamos blur en los botones secundarios. El primario destaca por
    // su color de marca y no necesita el efecto. El ClipRRect alrededor del
    // BackdropFilter es obligatorio: sin él, el blur se extendería más allá
    // del border radius y se vería borroso por fuera de las esquinas.
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
                'La mejor experiencia gastronómica de la ciudad.',
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
