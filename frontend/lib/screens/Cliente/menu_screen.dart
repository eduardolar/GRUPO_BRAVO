import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../services/api_service.dart';
import '../../components/Cliente/producto_card.dart';
import '../../models/producto_model.dart';
import '../../providers/cart_provider.dart';
import 'delivery_options_screen.dart';
import 'perfil_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _selectedCategory = 0;
  List<String> _categorias = [];
  List<Producto> _productos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final categorias = await ApiService.obtenerCategorias();
      final productos = await ApiService.obtenerProductos();
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _productos = productos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  void _addToCart(BuildContext context, Producto product) {
    Provider.of<CartProvider>(context, listen: false).addItem(product);
    _showSnack(context, '${product.nombre} añadido al pedido');
  }

  void _showSnack(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check, color: Colors.white, size: 15),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensaje.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.button,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 112),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pantalla de carga — imagen de fondo desde el inicio
    if (_cargando) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/Bravo restaurante.jpg',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.60),
                ),
              ),
            ),
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 1.5),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'CARGANDO CARTA',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      letterSpacing: 3.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final currentCategory =
        _categorias.isNotEmpty ? _categorias[_selectedCategory] : '';
    final filtered =
        _productos.where((p) => p.categoria == currentCategory).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Imagen del restaurante: fondo permanente de toda la pantalla ──
          Positioned.fill(
            child: Image.asset(
              'assets/images/Bravo restaurante.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // ── Overlay oscuro degradado ──────────────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.40),
                    Colors.black.withValues(alpha: 0.68),
                  ],
                ),
              ),
            ),
          ),

          // ── Contenido principal ───────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cabecera ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NUESTRA CARTA',
                              style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                shadows: const [
                                  Shadow(
                                      color: Colors.black54,
                                      blurRadius: 8),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Cocina de autor · Ingredientes frescos',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const CircleAvatar(
                          backgroundColor: Colors.white24,
                          radius: 18,
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PerfilScreen()),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ── Barra de categorías ───────────────────────────────────
                _CategoryBar(
                  categorias: _categorias,
                  selectedIndex: _selectedCategory,
                  onSelected: (i) =>
                      setState(() => _selectedCategory = i),
                ),

                const SizedBox(height: 14),

                // ── Lista de productos ────────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.restaurant_menu_outlined,
                                  size: 36, color: Colors.white30),
                              const SizedBox(height: 14),
                              const Text(
                                'SIN PLATOS DISPONIBLES',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10,
                                  letterSpacing: 3.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final columns = width >= 900
                                ? 3
                                : width >= 600
                                    ? 2
                                    : 1;
                            return GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 128),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 342,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final p = filtered[index];
                                return ProductoCard(
                                  product: p,
                                  onAdd: () => _addToCart(context, p),
                                  compactAdd: true,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _CartFAB(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const PantallaOpcionesEntrega()),
        ),
      ),
    );
  }
}

// ─── Barra de categorías (sobre imagen, modo oscuro) ─────────────────────────

class _CategoryBar extends StatefulWidget {
  final List<String> categorias;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _CategoryBar({
    required this.categorias,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  State<_CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<_CategoryBar> {
  final ScrollController _scroll = ScrollController();

  // Ancho estimado por chip para calcular el offset de scroll
  static const double _chipWidth = 110.0;
  static const double _chipSpacing = 8.0;

  @override
  void didUpdateWidget(_CategoryBar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    if (!_scroll.hasClients) return;
    final offset =
        (widget.selectedIndex * (_chipWidth + _chipSpacing)) - 16.0;
    _scroll.animateTo(
      offset.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Stack(
        children: [
          ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.categorias.length,
            itemBuilder: (context, index) {
              final isSelected = widget.selectedIndex == index;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => widget.onSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.button
                          : Colors.black45,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.button
                            : Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.categorias[index].toUpperCase(),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white70,
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Degradado derecho — indica que hay más categorías
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 40,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── FAB del carrito ──────────────────────────────────────────────────────────

class _CartFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _CartFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.totalQuantity == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Material(
            color: AppColors.button,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.white54, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          '${cart.totalQuantity}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'VER PEDIDO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    Text(
                      '${cart.totalPrice.toStringAsFixed(2).replaceAll('.', ',')} €',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right,
                        color: Colors.white54, size: 18),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
