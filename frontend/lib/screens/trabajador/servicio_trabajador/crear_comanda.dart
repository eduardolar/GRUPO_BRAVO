import 'package:flutter/material.dart';
import 'package:frontend/core/app_routes.dart';
import 'package:frontend/components/Cliente/producto_card.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/producto_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/trabajador/info_usuario.dart';
import 'package:frontend/services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class CrearComanda extends StatefulWidget {
  final String mesaId;
  /// Número visible de la mesa (e.g. 5), distinto del ObjectId.
  final int? numeroMesa;
  final String? pedidoIdExistente;
  final List<Map<String, dynamic>> productosExistentes;
  final double totalExistente;
  final VoidCallback? onPedidoEnviado;

  const CrearComanda({
    super.key,
    required this.mesaId,
    this.numeroMesa,
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
  bool _errorCarga = false;
  final Map<Producto, int> _carrito = {};
  String? _pedidoId;
  // Versión del pedido para concurrencia optimista. Cada PATCH exige enviar
  // la versión actual; el backend la incrementa y devuelve la nueva. Si dos
  // camareros editan a la vez, el segundo recibe 409 y debe recargar.
  int? _pedidoVersion;
  // Acumulado de todos los items ya enviados, clave = producto_id
  final Map<String, Map<String, dynamic>> _itemsAcumulados = {};
  double _totalAcumulado = 0.0;

  // Guard de doble-tap: true mientras hay un POST/PATCH en vuelo.
  bool _enviando = false;
  // Pedido marcado como urgente para cocina (banner rojo en pantalla cocinero).
  bool _prioritario = false;
  // Clave de idempotencia reutilizada en reintentos del mismo intento de envío.
  // Se renueva solo cuando el envío tiene éxito (carrito limpio) o cuando
  // el usuario navega fuera y vuelve (nuevo State).
  String _idempotencyKey = const Uuid().v4();

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
    setState(() {
      _cargando = true;
      _errorCarga = false;
    });
    try {
      // Pasamos el restauranteId del JWT para que la carta solo muestre los
      // productos de la sucursal del camarero. Sin esto, se mezclan platos
      // de todas las sucursales y un pedido a un producto ajeno fallaría
      // luego al descontar stock o al validar en el backend.
      final restauranteId =
          context.read<AuthProvider>().usuarioActual?.restauranteId;
      final results = await Future.wait([
        ApiService.obtenerCategorias(),
        ApiService.obtenerProductos(restauranteId: restauranteId),
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
      setState(() {
        _cargando = false;
        _errorCarga = true;
      });
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
        backgroundColor: AppColors.bottomSheetBg,
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

  /// Sale de la pantalla de toma de comanda. Lógica:
  ///   - Si ya se envió algún pedido (`_pedidoId != null`), la mesa queda
  ///     ocupada porque el cliente sigue ahí: solo popea.
  ///   - Si nunca se envió y el carrito está vacío, libera la mesa: el
  ///     camarero entró por error y sale sin dejar comanda.
  ///   - Si hay items en carrito sin enviar, pide confirmación. Al salir,
  ///     también libera la mesa (no hay pedido en marcha).
  Future<void> _volverAtras() async {
    if (_carrito.isEmpty) {
      await _liberarMesaSiSinPedido();
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bottomSheetBg,
        title: const Text(
          'Hay platos sin enviar',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tienes platos en el carrito que aún no se han enviado a cocina. '
          '¿Salir y descartarlos?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Seguir aquí',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Salir',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      await _liberarMesaSiSinPedido();
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  /// Si el camarero nunca llegó a enviar un pedido, devuelve la mesa al
  /// pool de libres. Si ya se envió, la mesa queda ocupada (el cliente
  /// sigue allí pendiente de servirse / cobrar).
  ///
  /// Si la liberación falla (p. ej. caída de red), avisamos al usuario en
  /// lugar de tragar el error en silencio: antes esto provocaba que la mesa
  /// quedara marcada como OCUPADA en el plano aunque no hubiera comanda.
  Future<void> _liberarMesaSiSinPedido() async {
    if (_pedidoId != null) return;
    try {
      await ApiService.marcarMesaLibre(widget.mesaId);
    } catch (e) {
      debugPrint('No se pudo liberar mesa ${widget.mesaId} al salir: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo liberar la mesa automáticamente. '
              'Refresca el plano y libérala manualmente si quedó ocupada.',
            ),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _enviarPedido(BuildContext context) async {
    // Guard de doble-tap: ignora pulsaciones mientras hay una petición en vuelo.
    if (_enviando) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _enviando = true);

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
        // Pedido ya existente: reemplazar items con la lista completa
        // acumulada. Pasamos la versión actual para concurrencia optimista;
        // si otro camarero editó este pedido entre tanto, el backend
        // devuelve 409 y este reintento falla limpiamente.
        final resultado = await ApiService.agregarItemsPedido(
          pedidoId: _pedidoId!,
          items: allItems,
          totalExtra: _totalAcumulado,
          version: _pedidoVersion,
        );
        final nuevaVersion = resultado['version'];
        if (nuevaVersion is int) _pedidoVersion = nuevaVersion;
      } else {
        // Primer envío: crear pedido nuevo y guardar su id.
        // _idempotencyKey persiste entre reintentos fallidos; se renueva
        // solo tras éxito (ver abajo).
        // userId se deja null: el backend persiste el sub del camarero
        // como usuario_id para mantener trazabilidad de quién creó la mesa.
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final resultado = await ApiService.crearPedido(
          items: allItems,
          tipoEntrega: "local",
          metodoPago: "efectivo",
          total: _totalAcumulado,
          direccionEntrega: null,
          mesaId: mesaId,
          numeroMesa: widget.numeroMesa,
          notas: "",
          referenciaPago: "",
          estadoPago: "pendiente",
          restauranteId: auth.usuarioActual?.restauranteId,
          idempotencyKey: _idempotencyKey,
          prioritario: _prioritario,
        );
        _pedidoId = (resultado['id'] ?? resultado['_id'])?.toString();
        final v = resultado['version'];
        _pedidoVersion = v is int ? v : 1;
      }

      if (!mounted) return;
      // Éxito: limpiamos carrito y renovamos la clave para el próximo envío.
      setState(() {
        _carrito.clear();
        _idempotencyKey = const Uuid().v4();
      });
      _showSnack(messenger, "Pedido enviado a cocina · puedes añadir más platos");
      widget.onPedidoEnviado?.call();

    } catch (e) {
      if (!mounted) return;
      // Si falla, deshacer el merge para no corromper el acumulado.
      // La _idempotencyKey NO se renueva: el usuario puede reintentar
      // con la misma clave y el backend lo tratará idempotentemente.
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
      // Mostramos el detalle del backend (409, 422, etc.) en el snack para
      // que sea diagnosticable en lugar de un genérico que oculte la causa.
      final detalle = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      _showSnack(
        messenger,
        detalle.isEmpty ? "Error al enviar pedido" : "Error: $detalle",
        error: true,
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
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
        backgroundColor: error ? AppColors.errorText : AppColors.button,
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
                      fontSize: 12,
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
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: Colors.white54,
                    ),
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
                    const SizedBox(height: 10),
                    const Text(
                      'Comprueba tu conexión y vuelve a intentarlo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        letterSpacing: 0.3,
                        height: 1.5,
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
                        backgroundColor: AppColors.button,
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
                  padding: const EdgeInsets.fromLTRB(8, 14, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: _volverAtras,
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
                            Text(
                              widget.numeroMesa != null
                                  ? 'Mesa ${widget.numeroMesa}'
                                  : 'Comanda en curso',
                              style: const TextStyle(
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
                        tooltip: 'Mi perfil',
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
                          AppRoute.slideUp(const PerfilTrabajadorScreen()),
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
                                  fontSize: 12,
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

                // Toggle "URGENTE" antes de mandar a cocina. Si está activo,
                // el pedido se crea con `prioritario=true` y el cocinero lo
                // ve destacado con banner rojo en su pantalla.
                if (_carrito.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: Colors.black.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.priority_high,
                          size: 16,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Marcar pedido como URGENTE para cocina',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Switch(
                          value: _prioritario,
                          onChanged: (v) =>
                              setState(() => _prioritario = v),
                          activeThumbColor: AppColors.error,
                        ),
                      ],
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
                      color: AppColors.surfaceDark,
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
                          color: AppColors.backgroundDark,
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
