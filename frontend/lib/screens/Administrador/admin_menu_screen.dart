import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:frontend/components/bravo_app_bar.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/producto_model.dart';
import 'package:frontend/screens/Administrador/admin_categorias_tab.dart';
import 'package:frontend/screens/Administrador/admin_editar_plato.dart';
import 'package:frontend/services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminMenuScreen extends StatefulWidget {
  const AdminMenuScreen({super.key});

  @override
  State<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends State<AdminMenuScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  int _selectedCategoryIndex = 0;
  List<String> _categorias = [];
  List<Producto> _productos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) setState(() {});
    });
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final categorias = await ApiService.obtenerCategorias();
      final productos = await ApiService.obtenerProductos();
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _productos = productos;
        if (_selectedCategoryIndex >= _categorias.length) {
          _selectedCategoryIndex = 0;
        }
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  void _reordenarProductos(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final categoria = _categorias[_selectedCategoryIndex];
    final filtrados = _productos.where((p) => p.categoria == categoria).toList();
    final otros = _productos.where((p) => p.categoria != categoria).toList();
    final original = List<Producto>.from(_productos);
    final reordenados = List<Producto>.from(filtrados);
    final moved = reordenados.removeAt(oldIndex);
    reordenados.insert(newIndex, moved);
    setState(() => _productos = [...reordenados, ...otros]);
    try {
      await ApiService.reordenarProductos(reordenados.map((p) => p.id).toList());
    } catch (_) {
      if (mounted) setState(() => _productos = original);
    }
  }

  Future<void> _abrirEditor({Producto? producto}) async {
    final hayCambios = await mostrarEditorProducto(context, producto: producto);
    if (hayCambios) await _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const BravoAppBar(title: 'LA CARTA'),
      body: Stack(
        children: [
          // Background image + gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/Bravo restaurante.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                _buildGlassTabBar(),
                Expanded(
                  child: _cargando
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        )
                      : AnimatedBuilder(
                          animation: _tabController,
                          builder: (context, _) => IndexedStack(
                            index: _tabController.index,
                            children: [
                              AdminCategoriasTab(onCambio: _cargarDatos),
                              _buildProductosTab(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _cargando || _tabController.index != 1
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab-prod',
              onPressed: () => _abrirEditor(),
              backgroundColor: AppColors.button,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo producto'),
            ),
    );
  }

  Widget _buildGlassTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.button,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              dividerColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              tabs: const [
                Tab(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category, size: 16),
                      SizedBox(width: 6),
                      Text('Categorías'),
                    ],
                  ),
                ),
                Tab(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu, size: 16),
                      SizedBox(width: 6),
                      Text('Productos'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── PRODUCTOS TAB ────────────────────────────────────────────

  Widget _buildProductosTab() {
    if (_categorias.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No hay categorías. Crea una desde la pestaña Categorías para empezar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final currentCategory = _categorias[_selectedCategoryIndex];
    final filteredProducts = _productos
        .where((p) => p.categoria == currentCategory)
        .toList();

    return Column(
      children: [
        const SizedBox(height: 6),
        _buildCategorySelector(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: filteredProducts.isEmpty
                ? Center(
                    key: ValueKey('vacio_$_selectedCategoryIndex'),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.no_food_outlined,
                            size: 48,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No hay productos en "$currentCategory"',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    key: ValueKey('lista_$_selectedCategoryIndex'),
                    color: AppColors.button,
                    onRefresh: _cargarDatos,
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: filteredProducts.length,
                      onReorder: _reordenarProductos,
                      proxyDecorator: (child, _, animation) => AnimatedBuilder(
                        animation: animation,
                        builder: (_, child) => Material(
                          elevation: 8,
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: child,
                        ),
                        child: child,
                      ),
                      itemBuilder: (_, index) {
                        final product = filteredProducts[index];
                        return Padding(
                          key: ValueKey(product.id),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SizedBox(
                            height: 140,
                            child: Stack(
                              children: [
                                _ProductoAdminCard(
                                  producto: product,
                                  onEditar: () =>
                                      _abrirEditor(producto: product),
                                ),
                                Positioned(
                                  top: 8,
                                  left: 10,
                                  child: ReorderableDragStartListener(
                                    index: index,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.drag_handle,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: List.generate(_categorias.length, (index) {
            final isSelected = _selectedCategoryIndex == index;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategoryIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.button
                      : Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.button
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _categorias[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Tarjeta de producto en modo admin con imagen full-bleed + gradiente.
class _ProductoAdminCard extends StatelessWidget {
  final Producto producto;
  final VoidCallback onEditar;

  const _ProductoAdminCard({required this.producto, required this.onEditar});

  @override
  Widget build(BuildContext context) {
    final imagen = producto.imagenUrl;
    final noDisp = !producto.estaDisponible;

    return GestureDetector(
      onTap: onEditar,
      child: Container(
        height: 140,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imagen != null && imagen.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imagen,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _imgFallback(),
                placeholder: (_, _) => _imgFallback(),
              )
            else
              _imgFallback(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 0.65, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (noDisp)
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AGOTADO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    producto.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 6),
                      ],
                    ),
                  ),
                  if (producto.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      producto.descripcion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${producto.precio.toStringAsFixed(2).replaceAll('.', ',')} €',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      _EditarPill(onTap: onEditar),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgFallback() => Container(
        color: Colors.black38,
        child: Icon(
          Icons.restaurant,
          color: Colors.white.withValues(alpha: 0.20),
          size: 32,
        ),
      );
}

class _EditarPill extends StatelessWidget {
  final VoidCallback onTap;
  const _EditarPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.button,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.edit, size: 13, color: Colors.white),
            SizedBox(width: 5),
            Text(
              'EDITAR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
