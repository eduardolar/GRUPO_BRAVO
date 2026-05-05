import 'package:flutter/material.dart';
import 'package:frontend/components/Cliente/producto_card.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/producto_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/Cliente/perfil_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CrearComanda extends StatefulWidget {
  final String mesaId;
  final String? pedidoIdExistente;
  final List<Map<String, dynamic>> productosExistentes;
  final double totalExistente;
  final VoidCallback? onPedidoEnviado;

  const CrearComanda({
    super.key,
    required this.mesaId,
    this.pedidoIdExistente,
    this.productosExistentes = const [],
    this.totalExistente = 0.0,
    this.onPedidoEnviado,
  });

  @override
  State<CrearComanda> createState() => _CrearPedidosState();
}

class _CrearPedidosState extends State<CrearComanda> {
  int _selectedCategory = 0;
  List<String> _categorias = [];
  List<Producto> _productos = [];
  bool _cargando = true;
  final Map<Producto, int> _carrito = {};
  String? _pedidoId;
  // Acumulado de todos los items ya enviados, clave = producto_id
  final Map<String, Map<String, dynamic>> _itemsAcumulados = {};
  double _totalAcumulado = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.pedidoIdExistente != null) {
      _pedidoId = widget.pedidoIdExistente;
      for (final item in widget.productosExistentes) {
        final id = (item['producto_id'] ?? item['productoId'] ?? item['_id'] ?? item['nombre'])?.toString() ?? '';
        if (id.isNotEmpty) {
          _itemsAcumulados[id] = Map<String, dynamic>.from(item);
        }
      }
      _totalAcumulado = widget.totalExistente;
    }
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final results = await Future.wait([
        ApiService.obtenerCategorias(),
        ApiService.obtenerProductos(),
        if (_pedidoId == null)
          ApiService.obtenerPedidoActivoPorMesa(widget.mesaId),
      ]);

      if (!mounted) return;

      final categorias = results[0] as List<String>;
      final productos = results[1] as List<Producto>;

      if (_pedidoId == null && results.length == 3) {
        final pedidoActivo = results[2] as Map<String, dynamic>?;
        if (pedidoActivo != null) {
          _pedidoId = (pedidoActivo['id'] ?? pedidoActivo['_id'])?.toString();
          final raw = pedidoActivo['productos'] ?? pedidoActivo['items'];
          if (raw is List) {
            for (final item in raw.cast<Map<String, dynamic>>()) {
              final id = (item['producto_id'] ?? item['productoId'] ?? item['_id'] ?? item['nombre'])?.toString() ?? '';
              if (id.isNotEmpty) _itemsAcumulados[id] = Map<String, dynamic>.from(item);
            }
          }
          _totalAcumulado = (pedidoActivo['total'] as num?)?.toDouble() ?? 0.0;
        }
      }

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

  void _pedirProducto(BuildContext context, Producto product) {
    setState(() {
      _carrito[product] = (_carrito[product] ?? 0) + 1;
    });
  }

  void _quitarProducto(Producto product) {
    setState(() {
      final qty = (_carrito[product] ?? 0) - 1;
      if (qty <= 0) {
        _carrito.remove(product);
      } else {
        _carrito[product] = qty;
      }
    });
  }

  int get _totalItems => _carrito.values.fold(0, (sum, qty) => sum + qty);

  double get _totalPrecio =>
      _carrito.entries.fold(0.0, (sum, e) => sum + e.key.precio * e.value);

  void _mostrarConfirmacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: const RoundedRectangleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Animación plato + tenedor ─────────────────────────
              Center(child: _PlateAnimation()),
              const SizedBox(height: 20),

              const Text(
                'CONFIRMAR PEDIDO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 16),

              ..._carrito.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        '× ${e.value}',
                        style: TextStyle(
                          color: AppColors.button,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.key.nombre,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '${(e.key.precio * e.value).toStringAsFixed(2).replaceAll(".", ",")} €',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(color: Colors.white24, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    '${_totalPrecio.toStringAsFixed(2).replaceAll(".", ",")} €',
                    style: TextStyle(
                      color: AppColors.button,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'CANCELAR',
                        style: TextStyle(
                          color: Colors.white54,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.button,
                        shape: const RoundedRectangleBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _enviarPedido(context);
                      },
                      child: const Text(
                        'ENVIAR A COCINA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _enviarPedido(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final mesaId = widget.mesaId;

      // Mergear carrito actual en el acumulado:
      // si el producto ya existe, sumar cantidades; si no, añadirlo
      for (final entry in _carrito.entries) {
        final id = entry.key.id;
        if (_itemsAcumulados.containsKey(id)) {
          _itemsAcumulados[id]!['cantidad'] =
              (_itemsAcumulados[id]!['cantidad'] as int) + entry.value;
        } else {
          _itemsAcumulados[id] = {
            "producto_id": id,
            "nombre": entry.key.nombre,
            "cantidad": entry.value,
            "precio": entry.key.precio,
          };
        }
      }
      _totalAcumulado += _totalPrecio;
      final allItems = _itemsAcumulados.values.toList();

      if (_pedidoId != null) {
        // Pedido ya existente: reemplazar items con la lista completa acumulada
        await ApiService.agregarItemsPedido(
          pedidoId: _pedidoId!,
          items: allItems,
          totalExtra: _totalAcumulado,
        );
      } else {
        // Primer envío: crear pedido nuevo y guardar su id
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final resultado = await ApiService.crearPedido(
          userId: "TRABAJADOR",
          items: allItems,
          tipoEntrega: "local",
          metodoPago: "efectivo",
          total: _totalAcumulado,
          direccionEntrega: null,
          mesaId: mesaId,
          numeroMesa: int.tryParse(mesaId),
          notas: "",
          referenciaPago: "",
          estadoPago: "pendiente",
          restauranteId: auth.usuarioActual?.restauranteId,
        );
        _pedidoId = (resultado['id'] ?? resultado['_id'])?.toString();
      }

    if (!mounted) return;
    setState(() => _carrito.clear());
    _showSnack(messenger, "Pedido enviado a cocina · puedes añadir más platos");
    widget.onPedidoEnviado?.call();

  } catch (e) {
    if (!mounted) return;
    // Si falla, deshacer el merge para no corromper el acumulado
    for (final entry in _carrito.entries) {
      final id = entry.key.id;
      final item = _itemsAcumulados[id];
      if (item != null) {
        final nuevaCantidad = (item['cantidad'] as int) - entry.value;
        if (nuevaCantidad <= 0) {
          _itemsAcumulados.remove(id);
        } else {
          item['cantidad'] = nuevaCantidad;
        }
      }
    }
    _totalAcumulado -= _totalPrecio;
    _showSnack(messenger, "Error al enviar pedido", error: true);
  }
}
      if (!mounted) return;
      setState(() => _carrito.clear());
      _showSnack(
        messenger,
        "Pedido enviado a cocina · puedes añadir más platos",
      );
    } catch (e) {
      if (!mounted) return;
      // Si falla, deshacer el merge para no corromper el acumulado
      for (final entry in _carrito.entries) {
        final id = entry.key.id;
        final item = _itemsAcumulados[id];
        if (item != null) {
          final nuevaCantidad = (item['cantidad'] as int) - entry.value;
          if (nuevaCantidad <= 0) {
            _itemsAcumulados.remove(id);
          } else {
            item['cantidad'] = nuevaCantidad;
          }
        }
      }
      _totalAcumulado -= _totalPrecio;
      _showSnack(messenger, "Error al enviar pedido", error: true);
    }
  }

  void _showSnack(
    ScaffoldMessengerState messenger,
    String mensaje, {
    bool error = false,
  }) {
    messenger.clearSnackBars();
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
        duration: const Duration(seconds: 3),
        backgroundColor: error ? Colors.red.shade800 : AppColors.button,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
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

    final currentCategory = _categorias.isNotEmpty
        ? _categorias[_selectedCategory]
        : '';
    final filtered = _productos
        .where((p) => p.categoria == currentCategory)
        .toList();

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
                            builder: (_) => const PerfilScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                _CategoryBar(
                  categorias: _categorias,
                  selectedIndex: _selectedCategory,
                  onSelected: (i) => setState(() => _selectedCategory = i),
                ),

                const SizedBox(height: 14),

                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.restaurant_menu_outlined,
                                size: 36,
                                color: Colors.white30,
                              ),
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
                                  onAdd: () => _pedirProducto(context, p),
                                  onRemove: () => _quitarProducto(p),
                                );
                              },
                            );
                          },
                        ),
                ),

                if (_carrito.isNotEmpty)
                  GestureDetector(
                    onTap: () => _mostrarConfirmacion(context),
                    child: Container(
                      width: double.infinity,
                      color: AppColors.button,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.restaurant,
                            color: Colors.white,
                            size: 17,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'MANDAR A COCINA · $_totalItems ${_totalItems == 1 ? "plato" : "platos"}',
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
    final offset = (widget.selectedIndex * (_chipWidth + _chipSpacing)) - 16.0;
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
                      color: isSelected ? AppColors.button : Colors.black45,
                      border: Border.all(
                        color: isSelected ? AppColors.button : Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.categorias[index].toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
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
// ─── Animación plato con tenedor ──────────────────────────────────────────────

class _PlateAnimation extends StatefulWidget {
  const _PlateAnimation();
  @override
  State<_PlateAnimation> createState() => _PlateAnimationState();
}

class _PlateAnimationState extends State<_PlateAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _stab; // tenedor baja y sube
  late final Animation<double> _wobble; // plato tiembla
  late final Animation<double> _scale; // plato crece un poco al pinchar

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(period: const Duration(milliseconds: 1400));

    // Tenedor: baja (0→1) entre 0%–40%, sube (1→0) entre 40%–70%, quieto el resto
    _stab = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    // Plato: tiembla cuando el tenedor pincha (40%–55%)
    _wobble = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 38),
      TweenSequenceItem(
        tween: TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 4.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 4.0, end: -4.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -4.0, end: 3.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 3.0, end: -2.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -2.0, end: 0.0), weight: 1),
        ]),
        weight: 17,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 45),
    ]).animate(_ctrl);

    // Plato escala ligeramente al impacto
    _scale = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 38),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 4),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 13),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // ── Plato ──────────────────────────────────────────
              Transform.translate(
                offset: Offset(_wobble.value, 0),
                child: Transform.scale(
                  scale: _scale.value,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2A2A2A),
                      border: Border.all(color: Colors.white12, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF222222),
                          border: Border.all(color: Colors.white10, width: 1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Tenedor ────────────────────────────────────────
              Transform.translate(
                offset: Offset(0, -50 + (_stab.value * 30)),
                child: Transform.rotate(
                  angle: 0.15,
                  child: Icon(
                    Icons.restaurant,
                    color: AppColors.button,
                    size: 32,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
