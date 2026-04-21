import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/restaurante_model.dart';
import '../../services/restaurante_service.dart';
import 'home_screen_super_admin.dart';
import '../../core/colors_style.dart';

class SeleccionarRestauranteScreen extends StatefulWidget {
  const SeleccionarRestauranteScreen({super.key});

  @override
  State<SeleccionarRestauranteScreen> createState() => _SeleccionarRestauranteScreenState();
}

class _SeleccionarRestauranteScreenState extends State<SeleccionarRestauranteScreen> {
  final RestauranteService _restauranteService = RestauranteService();
  late final Future<List<Restaurante>> _futureRestaurantes;

  @override
  void initState() {
    super.initState();
    // Iniciamos el future una sola vez para evitar rebuilds en hot reload
    _futureRestaurantes = _restauranteService.obtenerTodos();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── HERO INMERSIVO ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: screenHeight * 0.48,
            pinned: true,
            backgroundColor: AppColors.button,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _HeroHeader(),
              // Título compacto cuando está colapsado
              title: Text(
                'GRUPO BRAVO',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              centerTitle: true,
            ),
          ),

          // ── SECCIÓN LISTA ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
              child: Row(
                children: [
                  Container(width: 3, height: 18, color: AppColors.button),
                  const SizedBox(width: 10),
                  Text(
                    'SUCURSALES',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── ESTADOS: cargando / error / vacío / lista ──────────────
          FutureBuilder<List<Restaurante>>(
            future: _futureRestaurantes,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.button),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.wifi_off_outlined,
                    mensaje: 'No se pudieron cargar las sucursales.\nComprueba tu conexión e inténtalo de nuevo.',
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.storefront_outlined,
                    mensaje: 'No hay sucursales registradas todavía.',
                  ),
                );
              }

              final restaurantes = snapshot.data!;
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _RestauranteCard(
                      restaurante: restaurantes[index],
                      numero: index + 1,
                    ),
                    childCount: restaurantes.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── HERO HEADER ────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Imagen de fondo
        Positioned.fill(
          child: Image.asset(
            'assets/images/Bravo restaurante.jpg',
            fit: BoxFit.cover,
          ),
        ),

        // 2. Overlay degradado para legibilidad
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.70, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.55),
                  AppColors.background,
                ],
              ),
            ),
          ),
        ),

        // 3. Contenido centrado
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Badge "EST. 2024"
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white60, width: 1.2),
                  ),
                  child: Text(
                    'EST. 2024',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Título principal con Playfair Display
                const Text(
                  'GRUPO BRAVO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 16)],
                  ),
                ),
                const SizedBox(height: 10),

                // Subtítulo
                Text(
                  'Panel de Administración',
                  style: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),

                // Separador decorativo
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 32, height: 1, color: Colors.white30),
                    const SizedBox(width: 12),
                    const Icon(Icons.admin_panel_settings_outlined, color: Colors.white54, size: 18),
                    const SizedBox(width: 12),
                    Container(width: 32, height: 1, color: Colors.white30),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── TARJETA DE RESTAURANTE ──────────────────────────────────────────
class _RestauranteCard extends StatelessWidget {
  final Restaurante restaurante;
  final int numero;

  const _RestauranteCard({required this.restaurante, required this.numero});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreenSuperAdmin(
            restauranteId: restaurante.id,
            restauranteNombre: restaurante.nombre,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Acento lateral con número de sucursal
            Container(
              width: 52,
              color: AppColors.button,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                numero.toString().padLeft(2, '0'),
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Info de la sucursal
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurante.nombre,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            restaurante.direccion,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // CTA inline
                    Text(
                      'GESTIONAR →',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.button,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        ),
      ),
    );
  }
}

// ── ESTADO VACÍO / ERROR ────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String mensaje;

  const _EmptyState({required this.icon, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.line),
            const SizedBox(height: 16),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
