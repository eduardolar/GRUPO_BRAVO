import 'package:flutter/material.dart';
import 'package:frontend/components/Cliente/producto_card.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/producto_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'confirmar_pedido_domicilio.dart';

class PedidoDomicilio extends StatefulWidget {
  const PedidoDomicilio({super.key});

  @override
  State<PedidoDomicilio> createState() => _PedidoDomicilioState();
}

class _PedidoDomicilioState extends State<PedidoDomicilio> {
  int _selectedCategory = 0;
  List<String> _categorias = [];
  List<Producto> _productos = [];
  bool _cargando = true;
  bool _errorCarga = false;
  final Map<Producto, int> _carrito = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _errorCarga = false;
    });
    try {
      final restauranteId =
          context.read<AuthProvider>().usuarioActual?.restauranteId;
      final results = await Future.wait([
        ApiService.obtenerCategorias(),
        ApiService.obtenerProductos(restauranteId: restauranteId),
      ]);
      if (!mounted) return;
      setState(() {
        _categorias = results[0] as List<String>;
        _productos = results[1] as List<Producto>;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = true;
      });
    }
  }

  void _agregar(Producto p) => setState(() => _carrito[p] = (_carrito[p] ?? 0) + 1);

  void _quitar(Producto p) => setState(() {
        final qty = (_carrito[p] ?? 0) - 1;
        if (qty <= 0) {
          _carrito.remove(p);
        } else {
          _carrito[p] = qty;
        }
      });

  int get _totalItems => _carrito.values.fold(0, (s, q) => s + q);
  double get _totalPrecio =>
      _carrito.entries.fold(0.0, (s, e) => s + e.key.precio * e.value);

  void _irAConfirmar() {
    final items = _carrito.entries
        .map((e) => {
              'producto_id': e.key.id,
              'nombre': e.key.nombre,
              'cantidad': e.value,
              'precio': e.key.precio,
            })
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmarPedidoDomicilio(
          items: items,
          total: _totalPrecio,
        ),
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
            ),
          ],
        ),
      );
    }

    if (_errorCarga) {
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
                  color: Colors.black.withValues(alpha: 0.72),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.white54),
                    const SizedBox(height: 20),
                    Text(
                      'NO PUDIMOS CARGAR LA CARTA',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: _cargarDatos,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text(
                        'REINTENTAR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
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
          Positioned.fill(
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
                  colors: [
                    Colors.black.withValues(alpha: 0.40),
                    Colors.black.withValues(alpha: 0.68),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                        ),
                        iconSize: 18,
                        tooltip: 'Volver',
                      ),
                      const SizedBox(width: 4),
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
                              'Pedido a domicilio',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                _DomicilioCategoryBar(
                  categorias: _categorias,
                  selectedIndex: _selectedCategory,
                  onSelected: (i) => setState(() => _selectedCategory = i),
                ),

                const SizedBox(height: 14),

                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'SIN PLATOS DISPONIBLES',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              letterSpacing: 3.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 900
                                ? 3
                                : constraints.maxWidth >= 600
                                    ? 2
                                    : 1;
                            return GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 360,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final p = filtered[index];
                                return ProductoCard(
                                  product: p,
                                  quantity: _carrito[p] ?? 0,
                                  onAdd: () => _agregar(p),
                                  onRemove: () => _quitar(p),
                                );
                              },
                            );
                          },
                        ),
                ),

                if (_carrito.isNotEmpty)
                  GestureDetector(
                    onTap: _irAConfirmar,
                    child: Container(
                      width: double.infinity,
                      color: AppColors.primaryAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.delivery_dining,
                            color: Colors.white,
                            size: 17,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'SIGUIENTE · $_totalItems ${_totalItems == 1 ? "plato" : "platos"}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            '${_totalPrecio.toStringAsFixed(2).replaceAll('.', ',')} €',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Barra de categorías ──────────────────────────────────────────────────────
class _DomicilioCategoryBar extends StatefulWidget {
  final List<String> categorias;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _DomicilioCategoryBar({
    required this.categorias,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  State<_DomicilioCategoryBar> createState() => _DomicilioCategoryBarState();
}

class _DomicilioCategoryBarState extends State<_DomicilioCategoryBar> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.categorias.length,
        itemBuilder: (context, i) {
          final selected = i == widget.selectedIndex;
          return GestureDetector(
            onTap: () => widget.onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryAccent
                    : Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primaryAccent : Colors.white24,
                  width: 1,
                ),
              ),
              child: Text(
                widget.categorias[i].toUpperCase(),
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
