import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/app_routes.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/restaurante_model.dart';
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/providers/restaurante_provider.dart';

class SeleccionarRestauranteScreen extends StatefulWidget {
  final Widget siguiente;

  const SeleccionarRestauranteScreen({super.key, required this.siguiente});

  @override
  State<SeleccionarRestauranteScreen> createState() =>
      _SeleccionarRestauranteScreenState();
}

class _SeleccionarRestauranteScreenState
    extends State<SeleccionarRestauranteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RestauranteProvider>().cargar();
    });
  }

  void _seleccionar(Restaurante restaurante) {
    context.read<CartProvider>().seleccionarRestaurante(
          id: restaurante.id,
          nombre: restaurante.nombre,
        );
    Navigator.pushReplacement(
      context,
      AppRoute.slide(widget.siguiente),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fondo fotográfico
          Positioned.fill(
            child: Image.asset(
              'assets/images/Bravo restaurante.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Gradiente oscuro
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.50),
                    Colors.black.withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Expanded(child: _buildLista()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white30, width: 1),
            ),
            child: const Text(
              'BIENVENIDO',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 9,
                letterSpacing: 3.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Elige tu\nrestaurante',
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.15,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 14)],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Selecciona la sucursal donde te encuentras',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLista() {
    return Consumer<RestauranteProvider>(
      builder: (context, provider, _) {
        if (provider.cargando) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Colors.white54,
                strokeWidth: 1.5,
              ),
            ),
          );
        }

        if (provider.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 44, color: Colors.white30),
                  const SizedBox(height: 14),
                  const Text(
                    'No se pudieron cargar los restaurantes',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () => context.read<RestauranteProvider>().cargar(),
                    icon: const Icon(Icons.refresh,
                        color: Colors.white60, size: 18),
                    label: const Text(
                      'Reintentar',
                      style: TextStyle(
                        color: Colors.white60,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (provider.restaurantes.isEmpty) {
          return const Center(
            child: Text(
              'No hay restaurantes disponibles.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          itemCount: provider.restaurantes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final r = provider.restaurantes[index];
            return _RestauranteCard(
              restaurante: r,
              onTap: () => _seleccionar(r),
            );
          },
        );
      },
    );
  }
}

class _RestauranteCard extends StatelessWidget {
  final Restaurante restaurante;
  final VoidCallback onTap;

  const _RestauranteCard({required this.restaurante, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final abierto = restaurante.estaAbierto();
    final tieneHorario =
        restaurante.horarioApertura != null && restaurante.horarioCierre != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.button.withValues(alpha: 0.12),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.11),
            ),
          ),
          child: Row(
            children: [
              // Icono local
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.button.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.button.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppColors.button,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurante.nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (restaurante.direccion.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 12, color: Colors.white38),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              restaurante.direccion,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (tieneHorario) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 11,
                            color: abierto
                                ? AppColors.disp.withValues(alpha: 0.75)
                                : AppColors.error.withValues(alpha: 0.75),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${restaurante.horarioApertura} – ${restaurante.horarioCierre}',
                            style: TextStyle(
                              fontSize: 11,
                              color: abierto
                                  ? AppColors.disp.withValues(alpha: 0.80)
                                  : AppColors.error.withValues(alpha: 0.80),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: abierto
                                  ? AppColors.disp.withValues(alpha: 0.12)
                                  : AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              abierto ? 'Abierto' : 'Cerrado',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: abierto
                                    ? AppColors.disp
                                    : AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white30,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
