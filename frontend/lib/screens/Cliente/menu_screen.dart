import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../services/api_service.dart';
import '../../services/pedido_service.dart';
import '../../components/Cliente/producto_card.dart';
import '../../components/Cliente/producto_detalle_sheet.dart';
import '../../models/producto_model.dart';
import '../../models/pedido_model.dart';
import '../../models/restaurante_model.dart';
import '../../providers/cart_provider.dart';
import '../../core/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/restaurante_provider.dart';
import 'delivery_options_screen.dart';
import 'perfil_screen.dart';
import 'seleccionar_restaurante_screen.dart';

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

  Restaurante? _restaurante;
  Pedido? _ultimoPedido;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final results = await Future.wait([
        ApiService.obtenerCategorias(),
        ApiService.obtenerProductos(),
      ]);
      if (!mounted) return;
      setState(() {
        _categorias = results[0] as List<String>;
        _productos = results[1] as List<Producto>;
        _cargando = false;
      });
      _cargarExtras();
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _cargarExtras() async {
    final cart = context.read<CartProvider>();
    final auth = context.read<AuthProvider>();

    // Cargar horario del restaurante seleccionado
    if (cart.restauranteId != null) {
      try {
        final provRest = context.read<RestauranteProvider>();
        if (provRest.restaurantes.isEmpty) await provRest.cargar();
        if (!mounted) return;
        final matches =
            provRest.restaurantes.where((r) => r.id == cart.restauranteId);
        if (matches.isNotEmpty && mounted) {
          setState(() => _restaurante = matches.first);
        }
      } catch (e) { debugPrint('$e'); }
    }

    // Cargar último pedido para el botón de re-order
    if (auth.estaAutenticado && auth.usuarioActual != null) {
      try {
        final pedidos = await PedidoService.obtenerHistorialPedidos(
          userId: auth.usuarioActual!.id,
        );
        if (!mounted) return;
        if (pedidos.isNotEmpty) {
          setState(() => _ultimoPedido = pedidos.first);
        }
      } catch (e) { debugPrint('$e'); }
    }
  }

  void _mostrarDetalle(BuildContext context, Producto product) {
    if (!product.estaDisponible) return;

    // Bloquear si la cocina está cerrada
    if (_restaurante != null && !_restaurante!.estaAbierto()) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.schedule, color: Colors.white, size: 15),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'COCINA CERRADA · REABRE A LAS ${_restaurante!.horarioApertura ?? '—'}'
                      .toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 112),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => ProductoDetalleSheet(
          producto: product,
          onAgregar: (excluidos, cantidad) {
            final cart = Provider.of<CartProvider>(context, listen: false);
            cart.addItem(
              product,
              ingredientesExcluidos: excluidos,
              cantidad: cantidad,
            );
            _showSnack(context, '${product.nombre} añadido al pedido');
          },
        ),
      ),
    );
  }

  void _reordenar(Pedido pedido) {
    final cart = context.read<CartProvider>();
    int agregados = 0;
    for (final pp in pedido.productos) {
      if (pp.productoId == null) continue;
      final matches = _productos.where((p) => p.id == pp.productoId);
      if (matches.isEmpty) continue;
      final producto = matches.first;
      if (!producto.estaDisponible) continue;
      cart.addItem(
        producto,
        ingredientesExcluidos: pp.sin,
        cantidad: pp.cantidad,
      );
      agregados++;
    }
    if (agregados > 0) {
      _showSnack(context, 'Pedido anterior añadido al carrito');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo repetir (productos no disponibles)'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(),
          margin: EdgeInsets.fromLTRB(16, 0, 16, 112),
        ),
      );
    }
  }

  void _cambiarRestaurante() {
    final cart = context.read<CartProvider>();
    if (cart.totalQuantity > 0) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Cambiar restaurante',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Al cambiar de restaurante se vaciará tu carrito actual.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _irASeleccionarRestaurante();
              },
              child: const Text('Cambiar', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      _irASeleccionarRestaurante();
    }
  }

  void _irASeleccionarRestaurante() {
    context.read<CartProvider>().limpiarRestaurante();
    Navigator.pushReplacement(
      context,
      AppRoute.slide(const SeleccionarRestauranteScreen(siguiente: MenuScreen())),
    );
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
    final cocineraCerrada = _restaurante != null && !_restaurante!.estaAbierto();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Imagen de fondo
          Positioned.fill(
            child: Image.asset(
              'assets/images/Bravo restaurante.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Overlay oscuro
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

          // Contenido principal
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera
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
                                      color: Colors.black54, blurRadius: 8),
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
                            const SizedBox(height: 6),
                            Consumer<CartProvider>(
                              builder: (_, cart, _) {
                                if (cart.restauranteNombre == null) return const SizedBox.shrink();
                                return GestureDetector(
                                  onTap: _cambiarRestaurante,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.store_outlined, color: Colors.white38, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        cart.restauranteNombre!,
                                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.sync, color: AppColors.gold, size: 12),
                                    ],
                                  ),
                                );
                              },
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

                const SizedBox(height: 10),

                // Banner cocina cerrada
                if (cocineraCerrada)
                  _CerradoBanner(restaurante: _restaurante!),

                // Banner re-order
                if (_ultimoPedido != null && _ultimoPedido!.productos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 6),
                    child: _ReorderBanner(
                      pedido: _ultimoPedido!,
                      onReorder: () => _reordenar(_ultimoPedido!),
                    ),
                  ),

                const SizedBox(height: 8),

                // Barra de categorías
                _CategoryBar(
                  categorias: _categorias,
                  selectedIndex: _selectedCategory,
                  onSelected: (i) =>
                      setState(() => _selectedCategory = i),
                ),

                const SizedBox(height: 14),

                // Lista de productos
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
                              padding: const EdgeInsets.fromLTRB(
                                  16, 4, 16, 128),
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
                                  onAdd: () =>
                                      _mostrarDetalle(context, p),
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

// ─── Banner cocina cerrada ────────────────────────────────────────────────────

class _CerradoBanner extends StatelessWidget {
  final Restaurante restaurante;
  const _CerradoBanner({required this.restaurante});

  @override
  Widget build(BuildContext context) {
    final reapertura = restaurante.horarioApertura ?? '—';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppColors.error.withValues(alpha: 0.88),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: Colors.white, size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'COCINA CERRADA · Reabre a las $reapertura',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Banner re-order ──────────────────────────────────────────────────────────

class _ReorderBanner extends StatelessWidget {
  final Pedido pedido;
  final VoidCallback onReorder;
  const _ReorderBanner({required this.pedido, required this.onReorder});

  @override
  Widget build(BuildContext context) {
    final nombres =
        pedido.productos.take(3).map((p) => p.nombre).join(', ');
    final extra = pedido.productos.length > 3
        ? ' +${pedido.productos.length - 3} más'
        : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        border: Border.all(
            color: AppColors.button.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, color: AppColors.button, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PEDIDO ANTERIOR',
                  style: TextStyle(
                    color: AppColors.button,
                    fontSize: 9,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$nombres$extra',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onReorder,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              color: AppColors.button,
              child: const Text(
                'REPETIR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Barra de categorías ──────────────────────────────────────────────────────

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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
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
