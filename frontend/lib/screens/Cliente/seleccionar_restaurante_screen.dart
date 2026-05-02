import 'package:flutter/material.dart';
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(),
            Expanded(child: _Body(onSeleccionar: _seleccionar)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.button, width: 1.2),
            ),
            child: const Text(
              'BIENVENIDO',
              style: TextStyle(
                color: AppColors.button,
                fontSize: 10,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Elige tu\nrestaurante',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 36,
              fontWeight: FontWeight.bold,
              height: 1.15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Selecciona la sucursal en la que te encuentras para continuar.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final void Function(Restaurante) onSeleccionar;

  const _Body({required this.onSeleccionar});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestauranteProvider>();

    if (provider.cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.button),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                'No se pudieron cargar los restaurantes.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => context.read<RestauranteProvider>().cargar(),
                icon: const Icon(Icons.refresh, color: AppColors.button),
                label: const Text('Reintentar', style: TextStyle(color: AppColors.button)),
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
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      itemCount: provider.restaurantes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final r = provider.restaurantes[index];
        return _RestauranteCard(restaurante: r, onTap: () => onSeleccionar(r));
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
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.button.withValues(alpha: 0.08),
                  border: Border.all(color: AppColors.button.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.storefront_outlined, color: AppColors.button, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurante.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (restaurante.direccion.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              restaurante.direccion,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
