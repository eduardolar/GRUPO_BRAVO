import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- IMPORTACIONES DE TU PROYECTO ---
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/cliente/scanner_qr.dart';
import 'package:frontend/screens/cliente/login_screen.dart';
import 'package:frontend/models/destino_login.dart';
import 'package:frontend/screens/cliente/menu_screen.dart';
import 'package:frontend/screens/cliente/reservar_mesa_screen.dart';
import 'package:frontend/screens/cliente/pedido_confirmado_screen.dart';
import 'package:frontend/components/bravo_app_bar.dart';
import 'package:frontend/core/app_routes.dart';
import 'package:frontend/screens/cliente/seleccionar_restaurante_screen.dart';
import 'package:frontend/core/colors_style.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isAppReady = false;

  // Datos del redirect de Stripe (solo web)
  String? _stripeSessionId;
  String _stripeEntrega = '';
  double _stripeTotal = 0;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      final params = Uri.base.queryParameters;
      final sessionId = params['stripe_session'];
      if (sessionId != null && sessionId.isNotEmpty) {
        _stripeSessionId = sessionId;
        _stripeEntrega = Uri.decodeComponent(params['entrega'] ?? 'Tu pedido');
        _stripeTotal = double.tryParse(params['total'] ?? '0') ?? 0;
      }
    }
  }

  void _onSplashFinished() {
    setState(() => _isAppReady = true);
    if (_stripeSessionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verificarStripeRedirect());
    }
  }

  Future<void> _verificarStripeRedirect() async {
    final sessionId = _stripeSessionId!;
    _stripeSessionId = null;
    try {
      final pagado = await ApiService.verificarCheckoutSession(sessionId: sessionId);
      if (!mounted || !pagado) return;
      await ApiService.actualizarEstadoPago(referenciaPago: sessionId);
      if (!mounted) return;
      Navigator.push(
        context,
        AppRoute.reveal(PedidoConfirmadoScreen(
          tipoEntrega: _stripeEntrega,
          tipoPago: 'Tarjeta',
          total: _stripeTotal,
          pedidoId: sessionId,
        )),
      );
    } catch (e) { debugPrint('$e'); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: _isAppReady
            ? const _HomeContent()
            : _SimpleSplash(onFinished: _onSplashFinished),
      ),
    );
  }
}

// ── SPLASH INICIAL ──────────────────────────────────────────────
class _SimpleSplash extends StatefulWidget {
  final VoidCallback onFinished;
  const _SimpleSplash({required this.onFinished});

  @override
  State<_SimpleSplash> createState() => _SimpleSplashState();
}

class _SimpleSplashState extends State<_SimpleSplash> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), widget.onFinished);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 800),
          builder: (context, value, child) => Transform.scale(scale: value, child: child),
          child: Image.asset('assets/images/Bravo restaurante.jpg', width: 220),
        ),
      ),
    );
  }
}

// ── CONTENIDO PRINCIPAL ──────────────────────────────────────────
class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final nombreRestaurante = cart.restauranteNombre?.toUpperCase() ?? 'RESTAURANTE BRAVO';
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: BravoAppBar(title: nombreRestaurante, isRoot: true),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const _HeroSection(),
            const _FooterQuote(),
          ],
        ),
      ),
    );
  }
}


// ── SECCIÓN HERO (CENTRADA Y RESPONSIVA) ──────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWeb = screenWidth > 600;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // 1. Imagen de Fondo Inmersiva
        SizedBox(
          width: screenWidth,
          height: isWeb ? screenHeight * 0.85 : screenHeight * 0.75,
          child: Image.asset(
            'assets/images/Bravo restaurante.jpg',
            fit: BoxFit.cover,
          ),
        ),

        // 2. Overlay Gradiente de Alto Contraste
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.3, 0.7, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                  AppColors.background,
                ],
              ),
            ),
          ),
        ),

        // 3. Contenido Centrado
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500), // Ancho ideal para botones
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildBadge(),
                  const SizedBox(height: 24),
                  const Text(
                    "Hecho con tradición,\nservido con pasión.",
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
                  const SizedBox(height: 35),
                  const _ActionButtonsGroup(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.button, width: 1.5),
      ),
      child: const Text(
        "EST. 2024",
        style: TextStyle(
          color:  AppColors.line, 
          fontSize: 10, 
          letterSpacing: 4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── GRUPO DE BOTONES ─────────────────────────────────────────────
class _ActionButtonsGroup extends StatelessWidget {
  const _ActionButtonsGroup();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();

    return Column(
      children: [
        _MainButton(
          icon: Icons.qr_code_scanner,
          label: cart.tienemesa ? "Mesa ${cart.numeroMesa} - Cambiar" : "Escanear QR de mesa",
          isPrimary: true,
          onPressed: () => _handleQrScan(context),
        ),
        _MainButton(
          icon: Icons.motorcycle,
          label: "Pedido a domicilio",
          onPressed: () {
            final destino = auth.estaAutenticado
                ? const MenuScreen()
                : const LoginScreen();
            Navigator.push(
              context,
              cart.restauranteId != null
                  ? AppRoute.slide(destino)
                  : AppRoute.slide(SeleccionarRestauranteScreen(siguiente: destino)),
            );
          },
        ),
        _MainButton(
          icon: Icons.calendar_month,
          label: "Reservar mesa",
          onPressed: () {
            final destino = auth.estaAutenticado
                ? const ReservarMesaScreen()
                : const LoginScreen(destino: DestinoLogin.reservar);
            Navigator.push(
              context,
              cart.restauranteId != null
                  ? AppRoute.slide(destino)
                  : AppRoute.slide(SeleccionarRestauranteScreen(siguiente: destino)),
            );
          },
        ),
      ],
    );
  }

  Future<void> _handleQrScan(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final codigoQr = await Navigator.push<String>(context, AppRoute.slideUp(const QRScanner()));
    if (codigoQr == null) return;

    try {
      final resultado = await ApiService.validarQrMesa(codigoQr: codigoQr);
      final mesaId = resultado['mesa_id'] as String;
      final numMesa = int.tryParse(resultado['numero_mesa'].toString()) ?? 0;

      cart.asignarMesa(mesaId: mesaId, numeroMesa: numMesa);
      if (!context.mounted) return;

      final auth = context.read<AuthProvider>();
      Navigator.push(
        context,
        auth.estaAutenticado
            ? AppRoute.slide(const MenuScreen())
            : AppRoute.slideUp(const LoginScreen(destino: DestinoLogin.menu)),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }
}

// ── BOTÓN MODULAR ────────────────────────────────────────────────
class _MainButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _MainButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: isPrimary ? AppColors.button : Colors.black.withValues(alpha: 0.55),
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            decoration: BoxDecoration(
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
                const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── FOOTER ───────────────────────────────────────────────────────
class _FooterQuote extends StatelessWidget {
  const _FooterQuote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.background,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          margin: const EdgeInsets.fromLTRB(24, 20, 24, 60),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: AppColors.panel,
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              Icon(Icons.format_quote, color: AppColors.button.withValues(alpha: 0.4), size: 30),
              const SizedBox(height: 16),
              const Text(
                "La mejor experiencia gastronómica de la ciudad.",
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