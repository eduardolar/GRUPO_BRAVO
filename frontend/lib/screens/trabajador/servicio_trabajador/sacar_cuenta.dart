import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/mesa_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/mesa_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class SacarCuenta extends StatefulWidget {
  /// Si se pasa, selecciona automáticamente esa mesa al cargar la pantalla
  /// y carga su pedido. Útil para entrar desde un atajo (ej. acción "Sacar
  /// cuenta" en una fila de Gestión de Pedidos).
  final String? mesaIdInicial;

  const SacarCuenta({super.key, this.mesaIdInicial});

  @override
  State<SacarCuenta> createState() => _SacarCuentaState();
}

class _SacarCuentaState extends State<SacarCuenta> {
  List<Mesa> _mesasOcupadas = [];
  bool _cargandoMesas = true;
  // Solo aplica cuando se entra vía atajo (mesaIdInicial). Si tras cargar
  // mesas no encontramos la preseleccionada, mostramos un error en lugar
  // del spinner infinito que veíamos antes.
  bool _atajoFallido = false;

  Mesa? _mesaSeleccionada;
  Map<String, dynamic>? _pedido;
  bool _cargandoPedido = false;
  bool _procesando = false;

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
        _cargandoMesas = false;
      });

      // Atajo: si entramos con una mesa preseleccionada, cargamos su pedido
      // directamente sin obligar al camarero a re-elegirla en la lista.
      // Buscamos en TODAS las mesas (no solo ocupadas): en pedidos del tab
      // "Cobrar" la mesa puede estar marcada libre si el flujo se ejecutó
      // parcialmente antes; aún así queremos cobrar el pedido pendiente.
      final preId = widget.mesaIdInicial;
      if (preId != null && preId.isNotEmpty) {
        final mesa = todas.where((m) => m.id == preId).firstOrNull;
        if (mesa != null && mounted) {
          _seleccionarMesa(mesa);
        } else if (mounted) {
          // Atajo no resoluble: la mesa del pedido seleccionado ya no existe
          // en la lista (puede haberse borrado, o el pedido tiene mesa_id
          // huérfano). Mostramos error claro en vez de spinner infinito.
          setState(() => _atajoFallido = true);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoMesas = false;
        if (widget.mesaIdInicial != null) _atajoFallido = true;
      });
    }
  }

  Future<void> _seleccionarMesa(Mesa mesa) async {
    setState(() {
      _mesaSeleccionada = mesa;
      _pedido = null;
      _cargandoPedido = true;
    });

    try {
      final pedido = await ApiService.obtenerPedidoActivoPorMesa(mesa.id);
      if (!mounted) return;
      setState(() {
        _pedido = pedido;
        _cargandoPedido = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargandoPedido = false);
    }
  }

  Future<void> _cobrarYLiberarMesa(String metodoPago) async {
    // Guard de doble-tap: _procesando ya actúa como flag; comprobamos antes
    // de entrar para que sea explícito y simétrico con crear_comanda.
    if (_procesando) return;

    final pedidoId = (_pedido?['id'] ?? _pedido?['_id'])?.toString();
    final mesa = _mesaSeleccionada;
    if (pedidoId == null || mesa == null) return;

    // Generamos la clave UNA VEZ por intento de cobro.  Si el usuario
    // pulsa de nuevo después de un error, _procesando lo bloquea antes de
    // llegar aquí, por lo que no hace falta persistir la clave entre reintentos
    // a nivel de campo de estado (la pantalla completa de cobro se resetea).
    final idempotencyKey = const Uuid().v4();

    setState(() => _procesando = true);
    // Separamos las dos operaciones para diagnosticar cuál falla. Si falla
    // el cobro, no tocamos la mesa. Si falla la liberación de mesa tras un
    // cobro exitoso, alertamos explícitamente para que el camarero la libere
    // a mano (el dinero ya está cobrado, no se puede deshacer sin más).
    try {
      await ApiService.cerrarPedido(
        pedidoId: pedidoId,
        metodoPago: metodoPago,
        idempotencyKey: idempotencyKey,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      final detalle = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      _showSnack('Error al cobrar: $detalle', error: true);
      return;
    }

    try {
      await ApiService.marcarMesaLibre(
        mesa.id,
        idempotencyKey: idempotencyKey,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      final detalle = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      // Cobro hecho pero mesa no liberada: damos info clara y dejamos que
      // el camarero pueda intentarlo de nuevo (no hacemos auto-pop).
      _showSnack(
        'Cobro OK pero la mesa no se liberó: $detalle',
        error: true,
      );
      return;
    }

    if (!mounted) return;
    _showSnack('Mesa ${mesa.numero} cerrada y liberada');
    setState(() {
      _mesasOcupadas.remove(mesa);
      _mesaSeleccionada = null;
      _pedido = null;
      _procesando = false;
    });
    // Si entramos vía atajo (Cobrar desde Gestión de Pedidos), tras el
    // cobro exitoso volvemos directamente: el camarero ya terminó la
    // tarea y no tiene sentido que se quede en el selector de mesas.
    if (widget.mesaIdInicial != null && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg.toUpperCase(),
          style: const TextStyle(
            color: AppColors.background,
            fontSize: 11,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: error ? AppColors.error : AppColors.button,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
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
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.background,
                          size: 18,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'SACAR LA CUENTA',
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

                // ── Cuerpo ──────────────────────────────────────
                // Cuando se entra vía atajo (mesaIdInicial), nunca enseñamos
                // la lista de mesas: o bien mostramos el panel de cuenta
                // (mesa cargada) o un loader/empty state mientras llega.
                // El selector de mesas solo aparece en el flujo clásico.
                Expanded(
                  child: _mesaSeleccionada == null
                      ? (widget.mesaIdInicial != null
                          ? (_atajoFallido
                              ? Center(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 32),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          size: 40,
                                          color: AppColors.error,
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'NO SE ENCONTRÓ LA MESA',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppColors.background,
                                            fontSize: 12,
                                            letterSpacing: 2.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'La mesa del pedido ya no existe o se cerró.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.button,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: const RoundedRectangleBorder(),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                          ),
                                          child: const Text(
                                            'VOLVER',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: AppColors.background,
                                      strokeWidth: 1.5,
                                    ),
                                  ),
                                ))
                          : _PanelMesas(
                              mesas: _mesasOcupadas,
                              cargando: _cargandoMesas,
                              onSeleccionar: _seleccionarMesa,
                            ))
                      : _PanelCuenta(
                          mesa: _mesaSeleccionada!,
                          pedido: _pedido,
                          cargando: _cargandoPedido,
                          procesando: _procesando,
                          onVolver: () {
                            // Si entramos vía atajo, "Volver" sale de la
                            // pantalla en lugar de mostrar la lista de
                            // mesas (que el camarero no eligió, no aporta).
                            if (widget.mesaIdInicial != null) {
                              Navigator.of(context).pop();
                              return;
                            }
                            setState(() {
                              _mesaSeleccionada = null;
                              _pedido = null;
                            });
                          },
                          onCobrar: _cobrarYLiberarMesa,
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

// ─── Lista de mesas ocupadas ──────────────────────────────────────────────────

class _PanelMesas extends StatelessWidget {
  final List<Mesa> mesas;
  final bool cargando;
  final ValueChanged<Mesa> onSeleccionar;

  const _PanelMesas({
    required this.mesas,
    required this.cargando,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            color: AppColors.background,
            strokeWidth: 1.5,
          ),
        ),
      );
    }

    if (mesas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_restaurant_outlined,
              size: 40,
              color: AppColors.background,
            ),
            const SizedBox(height: 14),
            const Text(
              'NO HAY MESAS OCUPADAS',
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
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            itemCount: mesas.length,
            itemBuilder: (_, i) {
              final mesa = mesas[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSeleccionar(mesa),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        border: Border.all(color: AppColors.background),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.background,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Detalle de la cuenta ─────────────────────────────────────────────────────

class _PanelCuenta extends StatelessWidget {
  final Mesa mesa;
  final Map<String, dynamic>? pedido;
  final bool cargando;
  final bool procesando;
  final VoidCallback onVolver;
  final void Function(String metodoPago) onCobrar;

  const _PanelCuenta({
    required this.mesa,
    required this.pedido,
    required this.cargando,
    required this.procesando,
    required this.onVolver,
    required this.onCobrar,
  });

  List<Map<String, dynamic>> get _items {
    // el backend devuelve la lista bajo 'productos'; 'items' es el contador numérico
    final raw = pedido?['productos'] ?? pedido?['items'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  double get _total {
    final t = pedido?['total'];
    if (t == null) return 0.0;
    return (t as num).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera de mesa
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: onVolver,
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.background,
                ),
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'MESA ${mesa.numero}',
                style: const TextStyle(
                  color: AppColors.background,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.mesaSeleccionada.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.mesaSeleccionada,
                    width: 1,
                  ),
                ),
                child: const Text(
                  'OCUPADA',
                  style: TextStyle(
                    color: AppColors.mesaSeleccionada,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Contenido
        Expanded(
          child: cargando
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: AppColors.background,
                      strokeWidth: 1.5,
                    ),
                  ),
                )
              : pedido == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 40,
                        color: AppColors.background,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'SIN PEDIDO ACTIVO',
                        style: TextStyle(
                          color: AppColors.background,
                          fontSize: 11,
                          letterSpacing: 3.0,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.shadow,
                        border: Border.all(color: AppColors.background),
                      ),
                      child: Column(
                        children: [
                          ..._items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '× ${item['cantidad']}',
                                    style: TextStyle(
                                      color: AppColors.button,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      (item['nombre'] ?? '').toString(),
                                      style: const TextStyle(
                                        color: AppColors.background,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${((item['precio'] as num? ?? 0) * (item['cantidad'] as num? ?? 1)).toStringAsFixed(2).replaceAll('.', ',')} €',
                                    style: const TextStyle(
                                      color: AppColors.background,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(color: AppColors.background, height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'TOTAL',
                                  style: TextStyle(
                                    color: AppColors.background,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                Container(
                                  color: AppColors.backgroundButton,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    '${_total.toStringAsFixed(2).replaceAll('.', ',')} €',
                                    style: const TextStyle(
                                      color: AppColors.background,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),

        // Botones de cobro
        if (!cargando && pedido != null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'MÉTODO DE PAGO',
                  style: TextStyle(
                    color: AppColors.background,
                    fontSize: 10,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _BotonMetodoPago(
                      icon: Icons.payments_outlined,
                      label: 'EFECTIVO',
                      procesando: procesando,
                      onTap: () => onCobrar('efectivo'),
                    ),
                    const SizedBox(width: 10),
                    _BotonMetodoPago(
                      icon: Icons.credit_card,
                      label: 'TARJETA',
                      procesando: procesando,
                      onTap: () => onCobrar('tarjeta_fisica'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BotonMetodoPago extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool procesando;
  final VoidCallback onTap;

  const _BotonMetodoPago({
    required this.icon,
    required this.label,
    required this.procesando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: AppColors.button,
        child: InkWell(
          onTap: procesando ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: procesando
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: AppColors.background,
                        strokeWidth: 1.5,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: AppColors.background, size: 17),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.background,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
