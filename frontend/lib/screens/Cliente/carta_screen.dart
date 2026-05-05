import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../components/Cliente/empty_state.dart';
import '../../components/Cliente/producto_card.dart';
import '../../components/Cliente/producto_detalle_sheet.dart';
import '../../core/app_routes.dart';
import '../../core/colors_style.dart';
import '../../models/pedido_model.dart';
import '../../models/producto_model.dart';
import '../../models/restaurante_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/restaurante_provider.dart';
import '../../services/api_service.dart';
import '../../services/pedido_service.dart';
import 'opciones_entrega_screen.dart';
import 'perfil_screen.dart';
import 'seleccionar_restaurante_screen.dart';

const double _kFabBottomSpace = 128;
const BorderRadius _kRadius = BorderRadius.all(Radius.circular(12));
const Duration _kAnimFast = Duration(milliseconds: 180);

class CartaScreen extends StatefulWidget {
  const CartaScreen({super.key});

  @override
  State<CartaScreen> createState() => _CartaScreenState();
}

class _CartaScreenState extends State<CartaScreen> {
  int _selectedCategory = 0;
  List<String> _categorias = [];
  List<Producto> _productos = [];
  bool _cargando = true;
  bool _errorCarga = false;

  Restaurante? _restaurante;
  Pedido? _ultimoPedido;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // ── Carga ───────────────────────────────────────────────────────────────

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _errorCarga = false;
    });
    try {
      final results = await Future.wait([
        ApiService.obtenerCategorias(),
        ApiService.obtenerProductos(),
      ]);
      if (!mounted) return;
      setState(() {
        _categorias = results[0] as List<String>;
        _productos = results[1] as List<Producto>;
        _selectedCategory = 0;
        _cargando = false;
      });
      _cargarExtras();
    } catch (e) {
      debugPrint('Error cargando carta: $e');
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = true;
      });
    }
  }

  Future<void> _cargarExtras() async {
    final cart = context.read<CartProvider>();
    final auth = context.read<AuthProvider>();

    if (cart.restauranteId != null) {
      try {
        final provRest = context.read<RestauranteProvider>();
        if (provRest.restaurantes.isEmpty) await provRest.cargar();
        if (!mounted) return;
        final match = provRest.restaurantes
            .where((r) => r.id == cart.restauranteId)
            .firstOrNull;
        if (match != null) {
          setState(() => _restaurante = match);
        }
      } catch (e) {
        debugPrint('Error cargando restaurante: $e');
      }
    }

    if (auth.estaAutenticado && auth.usuarioActual != null) {
      try {
        final pedidos = await PedidoService.obtenerHistorialPedidos(
          userId: auth.usuarioActual!.id,
        );
        if (!mounted) return;
        if (pedidos.isNotEmpty) {
          setState(() => _ultimoPedido = pedidos.first);
        }
      } catch (e) {
        debugPrint('Error cargando último pedido: $e');
      }
    }
  }

  // ── Acciones ────────────────────────────────────────────────────────────

  void _mostrarDetalle(Producto producto) {
    if (!producto.estaDisponible) return;

    if (_restaurante != null && !_restaurante!.estaAbierto()) {
      _showSnack(
        'COCINA CERRADA · REABRE A LAS '
        '${(_restaurante!.horarioApertura ?? '—').toUpperCase()}',
        error: true,
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => ProductoDetalleSheet(
          producto: producto,
          onAgregar: (excluidos, cantidad) {
            sheetCtx.read<CartProvider>().addItem(
              producto,
              ingredientesExcluidos: excluidos,
              cantidad: cantidad,
            );
            _showSnack('${producto.nombre} añadido al pedido');
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
      final producto = _productos
          .where((p) => p.id == pp.productoId && p.estaDisponible)
          .firstOrNull;
      if (producto == null) continue;
      cart.addItem(
        producto,
        ingredientesExcluidos: pp.sin,
        cantidad: pp.cantidad,
      );
      agregados++;
    }
    if (agregados > 0) {
      _showSnack('Pedido anterior añadido al carrito');
    } else {
      _showSnack('No se pudo repetir (productos no disponibles)', error: true);
    }
  }

  Future<void> _cambiarRestaurante() async {
    final cart = context.read<CartProvider>();
    if (cart.totalQuantity == 0) {
      _irASeleccionarRestaurante();
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: const RoundedRectangleBorder(borderRadius: _kRadius),
        title: const Text(
          'Cambiar restaurante',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Al cambiar de restaurante se vaciará tu carrito actual.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cambiar',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      _irASeleccionarRestaurante();
    }
  }

  void _irASeleccionarRestaurante() {
    context.read<CartProvider>().limpiarRestaurante();
    Navigator.pushReplacement(
      context,
      AppRoute.slide(
        const SeleccionarRestauranteScreen(siguiente: CartaScreen()),
      ),
    );
  }

  void _irACheckout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PantallaOpcionesEntrega()),
    );
  }

  void _irAPerfil() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PerfilScreen()),
    );
  }

  void _showSnack(String mensaje, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check,
              color: Colors.white,
              size: 15,
            ),
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
        duration: Duration(seconds: error ? 3 : 2),
        backgroundColor: error ? AppColors.error : AppColors.button,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: _kRadius),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 112),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const _FondoConVelado(),
          SafeArea(
            child: _cargando
                ? const _CargandoCarta()
                : _errorCarga
                ? _ErrorCarta(onRetry: _cargarDatos)
                : _buildContenido(),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _CartFAB(onTap: _irACheckout),
    );
  }

  Widget _buildContenido() {
    final currentCategory = _categorias.isNotEmpty
        ? _categorias[_selectedCategory]
        : '';
    final filtered = _productos
        .where((p) => p.categoria == currentCategory)
        .toList(growable: false);
    final cocineraCerrada =
        _restaurante != null && !_restaurante!.estaAbierto();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Cabecera(
          onPerfil: _irAPerfil,
          onCambiarRestaurante: _cambiarRestaurante,
        ),
        const SizedBox(height: 10),
        if (cocineraCerrada) _CerradoBanner(restaurante: _restaurante!),
        if (_ultimoPedido != null && _ultimoPedido!.productos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: _ReorderBanner(
              pedido: _ultimoPedido!,
              onReorder: () => _reordenar(_ultimoPedido!),
            ),
          ),
        const SizedBox(height: 8),
        _CategoryBar(
          categorias: _categorias,
          selectedIndex: _selectedCategory,
          onSelected: (i) => setState(() => _selectedCategory = i),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarDatos,
            color: AppColors.button,
            child: _categorias.isEmpty
                ? const _SinCategorias()
                : filtered.isEmpty
                ? const _SinPlatosCategoria()
                : _GrillaProductos(productos: filtered, onTap: _mostrarDetalle),
          ),
        ),
      ],
    );
  }
}

// ── Widgets internos ─────────────────────────────────────────────────────

class _FondoConVelado extends StatelessWidget {
  const _FondoConVelado();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/Bravo restaurante.jpg',
              fit: BoxFit.cover,
            ),
            DecoratedBox(
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
          ],
        ),
      ),
    );
  }
}

class _CargandoCarta extends StatelessWidget {
  const _CargandoCarta();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 1.5,
            ),
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
    );
  }
}

class _ErrorCarta extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorCarta({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 14),
            const Text(
              'NO PUDIMOS CARGAR LA CARTA',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Comprueba tu conexión y vuelve a intentarlo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('REINTENTAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: _kRadius),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinCategorias extends StatelessWidget {
  const _SinCategorias();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 80),
        EmptyState.dark(
          icon: Icons.menu_book_outlined,
          title: 'Sin carta disponible',
          subtitle: 'Aún no se han publicado categorías en este restaurante.',
        ),
      ],
    );
  }
}

class _SinPlatosCategoria extends StatelessWidget {
  const _SinPlatosCategoria();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 80),
        EmptyState.dark(
          icon: Icons.restaurant_menu_outlined,
          title: 'Sin platos disponibles',
          subtitle: 'No hay productos en esta categoría.',
        ),
      ],
    );
  }
}

class _GrillaProductos extends StatelessWidget {
  final List<Producto> productos;
  final ValueChanged<Producto> onTap;
  const _GrillaProductos({required this.productos, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900
            ? 3
            : width >= 600
            ? 2
            : 1;
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, _kFabBottomSpace),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 342,
          ),
          itemCount: productos.length,
          itemBuilder: (context, index) {
            final p = productos[index];
            return ProductoCard(
              product: p,
              onAdd: () => onTap(p),
              compactAdd: true,
            );
          },
        );
      },
    );
  }
}

class _Cabecera extends StatelessWidget {
  final VoidCallback onPerfil;
  final VoidCallback onCambiarRestaurante;

  const _Cabecera({required this.onPerfil, required this.onCambiarRestaurante});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                      Shadow(color: Colors.black54, blurRadius: 8),
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
                _ChipRestaurante(onTap: onCambiarRestaurante),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Mi perfil',
            icon: const CircleAvatar(
              backgroundColor: Colors.white24,
              radius: 18,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            onPressed: onPerfil,
          ),
        ],
      ),
    );
  }
}

class _ChipRestaurante extends StatelessWidget {
  final VoidCallback onTap;
  const _ChipRestaurante({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (_, cart, _) {
        if (cart.restauranteNombre == null) return const SizedBox.shrink();
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.store_outlined,
                    color: Colors.white38,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    cart.restauranteNombre!,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.sync, color: AppColors.gold, size: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CerradoBanner extends StatelessWidget {
  final Restaurante restaurante;
  const _CerradoBanner({required this.restaurante});

  @override
  Widget build(BuildContext context) {
    final reapertura = restaurante.horarioApertura ?? '—';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.88),
        borderRadius: _kRadius,
      ),
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

class _ReorderBanner extends StatelessWidget {
  final Pedido pedido;
  final VoidCallback onReorder;
  const _ReorderBanner({required this.pedido, required this.onReorder});

  @override
  Widget build(BuildContext context) {
    final nombres = pedido.productos.take(3).map((p) => p.nombre).join(', ');
    final extra = pedido.productos.length > 3
        ? ' +${pedido.productos.length - 3} más'
        : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        borderRadius: _kRadius,
        border: Border.all(color: AppColors.button.withValues(alpha: 0.55)),
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
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: AppColors.button,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onReorder,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Text(
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
          ),
        ],
      ),
    );
  }
}

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
  final Map<int, GlobalKey> _chipKeys = {};

  @override
  void didUpdateWidget(_CategoryBar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToSelected();
      });
    }
  }

  void _scrollToSelected() {
    final key = _chipKeys[widget.selectedIndex];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      alignment: 0.1,
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
          ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.categorias.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isSelected = widget.selectedIndex == index;
              final chipKey = _chipKeys.putIfAbsent(index, () => GlobalKey());
              return _Chip(
                key: chipKey,
                label: widget.categorias[index],
                seleccionado: isSelected,
                onTap: () => widget.onSelected(index),
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

class _Chip extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final VoidCallback onTap;

  const _Chip({
    super.key,
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: _kAnimFast,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: seleccionado ? AppColors.button : Colors.black45,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: seleccionado ? AppColors.button : Colors.white24,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: seleccionado ? Colors.white : Colors.white70,
              fontSize: 11,
              fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

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
            borderRadius: _kRadius,
            elevation: 4,
            shadowColor: Colors.black54,
            child: InkWell(
              onTap: onTap,
              borderRadius: _kRadius,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${cart.totalQuantity}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                      size: 18,
                    ),
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
