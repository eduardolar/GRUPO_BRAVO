import 'package:flutter/material.dart';
import 'package:frontend/core/app_routes.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/mesa_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/mesa_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'crear_comanda.dart';

class ModificarComanda extends StatefulWidget {
  /// Si se pasa, salta el selector de mesas y abre directamente la comanda
  /// de esa mesa al cargar la pantalla. Útil para entrar desde un atajo
  /// (ej. acción "Modificar" en una fila de Gestión de Pedidos).
  final String? mesaIdInicial;

  const ModificarComanda({super.key, this.mesaIdInicial});

  @override
  State<ModificarComanda> createState() => _ModificarComandaState();
}

class _ModificarComandaState extends State<ModificarComanda> {
  List<Mesa> _mesasOcupadas = [];
  bool _cargando = true;
  String? _mesaCargandoId;

  @override
  void initState() {
    super.initState();
    _cargarMesas();
  }

  Future<void> _cargarMesas() async {
    final restauranteId = context.read<AuthProvider>().usuarioActual?.restauranteId;
    try {
      final todas = await MesaService.obtenerMesas(restauranteId: restauranteId);
      if (!mounted) return;
      setState(() {
        _mesasOcupadas = todas.where((m) => !m.disponible).toList();
        _cargando = false;
      });

      // Atajo: si entramos con una mesa preseleccionada, abrimos su comanda
      // sin obligar al camarero a re-elegirla en la lista.
      final preId = widget.mesaIdInicial;
      if (preId != null && preId.isNotEmpty) {
        final mesa = _mesasOcupadas.where((m) => m.id == preId).firstOrNull;
        if (mesa != null && mounted) {
          _abrirComanda(mesa);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _abrirComanda(Mesa mesa) async {
    setState(() => _mesaCargandoId = mesa.id);
    try {
      final pedido = await ApiService.obtenerPedidoActivoPorMesa(mesa.id);
      if (!mounted) return;
      setState(() => _mesaCargandoId = null);

      // Atajo: si entramos con mesa preseleccionada, al cerrar el sheet
      // volvemos directamente a la pantalla anterior en lugar de quedarnos
      // en el selector de mesas (que no aporta nada cuando se entra así).
      // El sheet devuelve `true` cuando el camarero ha pulsado AÑADIR
      // (navega a CrearComanda) — en ese caso no popeamos: el manejo del
      // stack lo hace la propia ruta de CrearComanda al volver.
      final eraAtajo = widget.mesaIdInicial != null &&
          widget.mesaIdInicial == mesa.id;
      final resultado = await _mostrarDetalleComanda(mesa, pedido);
      if (eraAtajo && mounted && resultado != true) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _mesaCargandoId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ERROR AL CARGAR EL PEDIDO'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(),
          margin: EdgeInsets.fromLTRB(16, 0, 16, 32),
        ),
      );
    }
  }

  Future<bool?> _mostrarDetalleComanda(Mesa mesa, Map<String, dynamic>? pedido) {
    final pedidoId = (pedido?['id'] ?? pedido?['_id'])?.toString();
    final productos = () {
      final raw = pedido?['productos'] ?? pedido?['items'];
      if (raw is List) return raw.cast<Map<String, dynamic>>();
      return <Map<String, dynamic>>[];
    }();
    final total = (pedido?['total'] as num?)?.toDouble() ?? 0.0;
    final parentContext = context;

    // El sheet devuelve `true` cuando el camarero ha navegado a otra
    // pantalla (ej. tocó "AÑADIR" → CrearComanda); en ese caso no debemos
    // hacer pop de ModificarComanda al cerrarse el sheet (rebotaría mal).
    final esAtajo = widget.mesaIdInicial != null && widget.mesaIdInicial == mesa.id;
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetalleComandaSheet(
        mesa: mesa,
        pedidoId: pedidoId,
        productos: productos,
        total: total,
        parentContext: parentContext,
        esAtajo: esAtajo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── AppBar ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: AppColors.background, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'MODIFICAR COMANDA',
                          style: GoogleFonts.playfairDisplay(
                            color: AppColors.background,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Lista de mesas ──────────────────────────────
                Expanded(child: _buildCuerpo()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCuerpo() {
    // Cuando entramos por un atajo (Modificar desde Gestión de Pedidos), el
    // BottomSheet se abre automáticamente sobre esta pantalla. Ocultamos la
    // lista de mesas para que no genere ruido visual: el camarero solo ve
    // el detalle del pedido seleccionado.
    if (widget.mesaIdInicial != null) {
      return const SizedBox.shrink();
    }
    if (_cargando) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              color: AppColors.background, strokeWidth: 1.5),
        ),
      );
    }

    if (_mesasOcupadas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.table_restaurant_outlined,
                size: 40, color: AppColors.background),
            const SizedBox(height: 14),
            const Text(
              'NO HAY CUENTAS ABIERTAS',
              style: TextStyle(
                color: AppColors.background,
                fontSize: 11,
                letterSpacing: 3.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'SELECCIONA LA MESA',
            style: TextStyle(
              color: AppColors.background,
              fontSize: 11,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.button,
            backgroundColor: Colors.black,
            onRefresh: _cargarMesas,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              itemCount: _mesasOcupadas.length,
              itemBuilder: (_, i) {
                final mesa = _mesasOcupadas[i];
                final cargando = _mesaCargandoId == mesa.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: cargando ? null : () => _abrirComanda(mesa),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          border:
                              Border.all(color: AppColors.background),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              color: AppColors.backgroundButton,
                              child: Center(
                                child: Text(
                                  '${mesa.numero}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MESA ${mesa.numero}',
                                    style: const TextStyle(
                                      color: AppColors.background,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${mesa.ubicacion.toUpperCase()} · ${mesa.capacidad} PAX',
                                    style: const TextStyle(
                                      color: AppColors.background,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            cargando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: AppColors.background,
                                        strokeWidth: 1.5),
                                  )
                                : const Icon(Icons.chevron_right,
                                    color: AppColors.background, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
// ─── Bottom sheet detalle de comanda ─────────────────────────────────────────

class _DetalleComandaSheet extends StatefulWidget {
  final Mesa mesa;
  final String? pedidoId;
  final List<Map<String, dynamic>> productos;
  final double total;
  final BuildContext parentContext;
  /// Cuando se entra al sheet vía atajo (ej. "Modificar" desde Gestión de
  /// Pedidos), al pulsar AÑADIR usamos `pushReplacement` para no dejar
  /// ModificarComanda muerto en el stack (mostraría una pantalla en blanco).
  final bool esAtajo;

  const _DetalleComandaSheet({
    required this.mesa,
    required this.pedidoId,
    required this.productos,
    required this.total,
    required this.parentContext,
    required this.esAtajo,
  });

  @override
  State<_DetalleComandaSheet> createState() => _DetalleComandaSheetState();
}

class _DetalleComandaSheetState extends State<_DetalleComandaSheet> {
  late List<Map<String, dynamic>> _productos;
  bool _guardando = false;
  bool _modificado = false;

  @override
  void initState() {
    super.initState();
    // Copia profunda mutable: cada item se clona para no compartir referencias
    // con la lista original (que pertenece al pedido cargado).
    _productos = widget.productos
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
  }

  double get _totalActual {
    double t = 0;
    for (final item in _productos) {
      final cantidad = (item['cantidad'] as num?)?.toInt() ?? 1;
      final precio = (item['precio'] as num?)?.toDouble() ?? 0.0;
      t += precio * cantidad;
    }
    return t;
  }

  void _decrementar(int index) {
    setState(() {
      final cantidad = (_productos[index]['cantidad'] as num?)?.toInt() ?? 1;
      if (cantidad > 1) {
        _productos[index]['cantidad'] = cantidad - 1;
      } else {
        _productos.removeAt(index);
      }
      _modificado = true;
    });
  }

  void _incrementar(int index) {
    setState(() {
      final cantidad = (_productos[index]['cantidad'] as num?)?.toInt() ?? 1;
      _productos[index]['cantidad'] = cantidad + 1;
      _modificado = true;
    });
  }

  Future<void> _guardarCambios() async {
    final pedidoId = widget.pedidoId;
    if (pedidoId == null || _guardando) return;
    // Capturamos el messenger antes del await para no usar el context
    // del widget tras el gap asíncrono.
    final messenger = ScaffoldMessenger.of(widget.parentContext);
    setState(() => _guardando = true);
    try {
      await ApiService.agregarItemsPedido(
        pedidoId: pedidoId,
        items: _productos,
        totalExtra: _totalActual,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('CAMBIOS GUARDADOS'),
          backgroundColor: AppColors.button,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(),
          margin: EdgeInsets.fromLTRB(16, 0, 16, 32),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      final detalle = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      messenger.showSnackBar(
        SnackBar(
          content: Text(detalle.isEmpty ? 'ERROR AL GUARDAR' : detalle),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        ),
      );
    }
  }

  // Aliases para no tocar el resto del build (que usa los nombres antiguos).
  Mesa get mesa => widget.mesa;
  String? get pedidoId => widget.pedidoId;
  List<Map<String, dynamic>> get productos => _productos;
  double get total => _totalActual;
  BuildContext get parentContext => widget.parentContext;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.90,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            border: Border(
              top: BorderSide(color: Colors.white12, width: 1),
            ),
          ),
          child: Column(
            children: [
              // ── Handle ──────────────────────────────────────
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Cabecera ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      color: AppColors.backgroundButton,
                      child: Center(
                        child: Text(
                          '${mesa.numero}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MESA ${mesa.numero}',
                            style: const TextStyle(
                              color: AppColors.background,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            '${mesa.ubicacion.toUpperCase()} · ${mesa.capacidad} PAX',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Botón modificar ───────────────────────
                    GestureDetector(
                      onTap: () {
                        // Cerramos el sheet con resultado `true` para que
                        // _abrirComanda sepa que el camarero ha navegado a
                        // CrearComanda y no dispare el auto-pop (que dejaría
                        // a ModificarComanda fuera del stack antes de tiempo).
                        Navigator.pop(context, true);
                        final navigator = Navigator.of(parentContext);
                        final ruta = AppRoute.slide(
                          CrearComanda(
                            mesaId: mesa.id,
                            pedidoIdExistente: pedidoId,
                            productosExistentes: productos,
                            totalExistente: total,
                            onPedidoEnviado: () {
                              // pop CrearComanda + pop ModificarComanda →
                              // el camarero vuelve a Gestión de Pedidos
                              // (o al selector si no era atajo).
                              Navigator.of(parentContext).pop();
                              Navigator.of(parentContext).pop();
                            },
                          ),
                        );
                        // Si se vino por atajo y el camarero hace back desde
                        // CrearComanda sin enviar, dejaríamos ModificarComanda
                        // visible con el body vacío → popeamos también para
                        // volver a Gestión de Pedidos. Si onPedidoEnviado
                        // ya popeó ModificarComanda, el mounted=false evita
                        // el doble pop.
                        navigator.push(ruta).then((_) {
                          // Comprobamos `parentContext.mounted` antes de usarlo
                          // — el analyzer no reconoce este patrón pero la
                          // guarda es correcta (false si ModificarComanda ya
                          // se popeó dentro de onPedidoEnviado).
                          // ignore: use_build_context_synchronously
                          if (widget.esAtajo && parentContext.mounted) {
                            // ignore: use_build_context_synchronously
                            Navigator.of(parentContext).pop();
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.button,
                          borderRadius: BorderRadius.zero,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'AÑADIR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const Divider(color: Colors.white10, height: 1),

              // ── Lista de productos ────────────────────────────
              Expanded(
                child: productos.isEmpty
                    ? const Center(
                        child: Text(
                          'SIN PRODUCTOS',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            letterSpacing: 2.5,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        itemCount: productos.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (_, i) {
                          final item = productos[i];
                          final cantidad = (item['cantidad'] as num?)?.toInt() ?? 1;
                          final nombre = (item['nombre'] ?? '').toString();
                          final precio = (item['precio'] as num?)?.toDouble() ?? 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Text(
                                  '× $cantidad',
                                  style: TextStyle(
                                    color: AppColors.button,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    nombre,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(precio * cantidad).toStringAsFixed(2).replaceAll('.', ',')} €',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: _guardando
                                      ? null
                                      : () => _decrementar(i),
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: AppColors.error,
                                    size: 22,
                                  ),
                                  tooltip: cantidad > 1
                                      ? 'Quitar 1'
                                      : 'Eliminar plato',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _guardando
                                      ? null
                                      : () => _incrementar(i),
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: AppColors.button,
                                    size: 22,
                                  ),
                                  tooltip: 'Añadir 1 más',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // ── Total ─────────────────────────────────────────
              if (productos.isNotEmpty) ...[
                const Divider(color: Colors.white12, height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL ACUMULADO',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${total.toStringAsFixed(2).replaceAll('.', ',')} €',
                        style: TextStyle(
                          color: AppColors.button,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Botón de guardar: solo aparece cuando el camarero ha tocado
              // algo (quitar plato o reducir cantidad). Hasta entonces no
              // hay nada que persistir.
              if (_modificado)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _guardarCambios,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.button,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 1.5,
                              ),
                            )
                          : const Text(
                              'GUARDAR CAMBIOS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                ),

              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }
}