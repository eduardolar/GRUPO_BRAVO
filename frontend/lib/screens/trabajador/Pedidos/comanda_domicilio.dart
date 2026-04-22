import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/trabajador/Pedidos/crear_pedidos.dart';
import 'package:frontend/screens/trabajador/Pedidos/pedido_domicilio.dart';
import 'package:frontend/screens/trabajador/Pedidos/seleccion_mesa.dart';
import 'package:frontend/screens/trabajador/Stock/avisar_falta.dart';
import 'package:frontend/screens/trabajador/Stock/bloquear_producto.dart';

class SeleccionPedido extends StatefulWidget {
  const SeleccionPedido({super.key});

  @override
  State<SeleccionPedido> createState() => _SeleccionPedidoState();
}

class _SeleccionPedidoState extends State<SeleccionPedido> {
  bool _isAppReady = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: _isAppReady
            ? const _StockContent()
            : _SimpleSplash(onFinished: () => setState(() => _isAppReady = true)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SPLASH
// ─────────────────────────────────────────────────────────────
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
          builder: (context, value, child) =>
              Transform.scale(scale: value, child: child),
          child: Image.asset('assets/images/Bravo restaurante.jpg', width: 220),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CONTENIDO PRINCIPAL
// ─────────────────────────────────────────────────────────────
class _StockContent extends StatelessWidget {
  const _StockContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: const _CustomAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: const [
            _HeroSectionStock(),
            _FooterQuote(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// APPBAR
// ─────────────────────────────────────────────────────────────
class _CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CustomAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        "GESTIÓN DE PEDIDOS",
        style: TextStyle(
          fontFamily: 'Playfair Display',
          color: AppColors.textAppBar,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: IconButton(
            icon: CircleAvatar(
              backgroundColor: Colors.white24,
              radius: 18,
              child: Icon(Icons.inventory_2_outlined,
                  color: Colors.white, size: 20),
            ),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// ─────────────────────────────────────────────────────────────
// HERO SECTION (con badge granate encima del título)
// ─────────────────────────────────────────────────────────────
class _HeroSectionStock extends StatelessWidget {
  const _HeroSectionStock();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWeb = screenWidth > 600;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          width: screenWidth,
          height: isWeb ? screenHeight * 0.85 : screenHeight * 0.75,
          child: Image.asset(
            'assets/images/Bravo restaurante.jpg',
            fit: BoxFit.cover,
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
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.black.withOpacity(0.75),
                  AppColors.background,
                ],
              ),
            ),
          ),
        ),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // BADGE GRANATE
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundButton,
                      border:
                          Border.all(color: AppColors.background, width: 1.5),
                    ),
                    child: const Text(
                      "GESTIÓN DE PEDIDOS",
                      style: TextStyle(
                        color: AppColors.background,
                        fontSize: 10,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    "Panel de pedidos",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      color: Colors.white,
                      fontSize: 38,
                      height: 1.1,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 15),
                      ],
                    ),
                  ),

                  const SizedBox(height: 35),

                  const _ActionButtonsStock(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTONES DE ACCIÓN
// ─────────────────────────────────────────────────────────────
class _ActionButtonsStock extends StatelessWidget {
  const _ActionButtonsStock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MainButton(
          icon: Icons.restaurant_menu_outlined,
          label: "Comanda en mesa",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SeleccionMesa()),
            );
          },
        ),
        _MainButton(
          icon: Icons.home_outlined,
          label: "A domicilio",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const PedidoDomicilio()),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTÓN MODULAR
// ─────────────────────────────────────────────────────────────
class _MainButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _MainButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppColors.button,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
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
                const Icon(Icons.chevron_right,
                    color: Colors.white54, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FOOTER
// ─────────────────────────────────────────────────────────────
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
              Icon(Icons.format_quote,
                  color: AppColors.button.withOpacity(0.4), size: 30),
              const SizedBox(height: 16),
              const Text(
                "Control y precisión en cada pedido.",
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
