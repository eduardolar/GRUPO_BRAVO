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

  Future<void> _cobrarYLiberarMesa(
    String metodoPago, {
    double descuento = 0,
    double propina = 0,
  }) async {
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
        descuento: descuento > 0 ? descuento : null,
        propina: propina > 0 ? propina : null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      final detalle = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      _showSnack('Error al cobrar: $detalle', error: true);
      return;
    }

    try {
      // Tras cobrar, la mesa NO va directa a libre: pasa a "por_limpiar"
      // para que el equipo de sala sepa que hay que recogerla. Cuando
      // alguien la marca limpia (desde el selector de mesas), pasa a libre.
      await ApiService.marcarMesaPorLimpiar(mesa.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      final detalle = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      _showSnack(
        'Cobro OK pero la mesa no se marcó por limpiar: $detalle',
        error: true,
      );
      return;
    }

    if (!mounted) return;
    _showSnack('Mesa ${mesa.numero} cobrada · pendiente de limpiar');
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
                        tooltip: 'Volver',
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

class _PanelCuenta extends StatefulWidget {
  final Mesa mesa;
  final Map<String, dynamic>? pedido;
  final bool cargando;
  final bool procesando;
  final VoidCallback onVolver;
  final void Function(
    String metodoPago, {
    double descuento,
    double propina,
  })
  onCobrar;

  const _PanelCuenta({
    required this.mesa,
    required this.pedido,
    required this.cargando,
    required this.procesando,
    required this.onVolver,
    required this.onCobrar,
  });

  @override
  State<_PanelCuenta> createState() => _PanelCuentaState();
}

class _PanelCuentaState extends State<_PanelCuenta> {
  // Ajustes de cobro: el camarero los puede tocar antes de elegir método.
  double _descuento = 0; // €
  double _propina = 0; // €
  int _dividirEn = 1; // calculadora informativa: parte por persona

  List<Map<String, dynamic>> get _items {
    final raw = widget.pedido?['productos'] ?? widget.pedido?['items'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  double get _subtotal {
    final t = widget.pedido?['total'];
    if (t == null) return 0.0;
    return (t as num).toDouble();
  }

  double get _totalCobrar {
    final t = _subtotal - _descuento + _propina;
    return t < 0 ? 0 : t;
  }

  double get _porPersona =>
      _dividirEn <= 1 ? _totalCobrar : _totalCobrar / _dividirEn;

  Future<void> _abrirDescuento() async {
    final ctrlImporte = TextEditingController(
      text: _descuento > 0 ? _descuento.toStringAsFixed(2) : '',
    );
    final resultado = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Aplicar descuento',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subtotal: ${_subtotal.toStringAsFixed(2).replaceAll('.', ',')} €',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrlImporte,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Descuento (€)',
                suffixText: '€',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final pct in const [5, 10, 15, 20])
                  ActionChip(
                    label: Text('-$pct%'),
                    onPressed: () {
                      ctrlImporte.text =
                          (_subtotal * pct / 100).toStringAsFixed(2);
                    },
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0.0),
            child: const Text(
              'QUITAR',
              style: TextStyle(color: AppColors.error),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(
                ctrlImporte.text.replaceAll(',', '.'),
              );
              if (v == null || v < 0) {
                Navigator.pop(ctx);
                return;
              }
              if (v > _subtotal) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('El descuento no puede superar el subtotal'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, v);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.button,
              shape: const RoundedRectangleBorder(),
            ),
            child: const Text(
              'APLICAR',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    ctrlImporte.dispose();
    if (resultado != null) {
      setState(() => _descuento = resultado);
    }
  }

  Future<void> _abrirPropina() async {
    final ctrlImporte = TextEditingController(
      text: _propina > 0 ? _propina.toStringAsFixed(2) : '',
    );
    final resultado = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Añadir propina',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subtotal: ${_subtotal.toStringAsFixed(2).replaceAll('.', ',')} €',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrlImporte,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Propina (€)',
                suffixText: '€',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final pct in const [5, 10, 15])
                  ActionChip(
                    label: Text('+$pct%'),
                    onPressed: () {
                      ctrlImporte.text =
                          (_subtotal * pct / 100).toStringAsFixed(2);
                    },
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0.0),
            child: const Text(
              'QUITAR',
              style: TextStyle(color: AppColors.error),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(
                ctrlImporte.text.replaceAll(',', '.'),
              );
              if (v == null || v < 0) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx, v);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.button,
              shape: const RoundedRectangleBorder(),
            ),
            child: const Text(
              'APLICAR',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    ctrlImporte.dispose();
    if (resultado != null) {
      setState(() => _propina = resultado);
    }
  }

  // Aliases para que el resto del build (que aún usa los nombres) funcione.
  Mesa get mesa => widget.mesa;
  Map<String, dynamic>? get pedido => widget.pedido;
  bool get cargando => widget.cargando;
  bool get procesando => widget.procesando;
  VoidCallback get onVolver => widget.onVolver;
  void onCobrar(String metodo) => widget.onCobrar(
    metodo,
    descuento: _descuento,
    propina: _propina,
  );

  Widget _filaDesglose(
    String label,
    double valor, {
    bool destacado = false,
    Color? color,
  }) {
    final signo = valor < 0 ? '-' : '';
    final abs = valor.abs().toStringAsFixed(2).replaceAll('.', ',');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color ?? AppColors.textSecondary,
              fontSize: destacado ? 13 : 12,
              fontWeight: destacado ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            '$signo$abs €',
            style: TextStyle(
              color: color ?? AppColors.background,
              fontSize: destacado ? 14 : 12,
              fontWeight: destacado ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
                tooltip: 'Volver',
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
                    fontSize: 11,
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
                          // Desglose: subtotal + ajustes (descuento/propina) + total
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                            child: Column(
                              children: [
                                _filaDesglose(
                                  'Subtotal',
                                  _subtotal,
                                  destacado: false,
                                ),
                                if (_descuento > 0)
                                  _filaDesglose(
                                    'Descuento',
                                    -_descuento,
                                    destacado: false,
                                    color: AppColors.error,
                                  ),
                                if (_propina > 0)
                                  _filaDesglose(
                                    'Propina',
                                    _propina,
                                    destacado: false,
                                    color: AppColors.disp,
                                  ),
                              ],
                            ),
                          ),
                          // Total destacado
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
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
                                    '${_totalCobrar.toStringAsFixed(2).replaceAll('.', ',')} €',
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
                          // Indicador "por persona" cuando se divide
                          if (_dividirEn > 1)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 14),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.button.withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: AppColors.button.withValues(alpha: 0.4),
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Dividido entre $_dividirEn → '
                                  '${_porPersona.toStringAsFixed(2).replaceAll('.', ',')} € '
                                  'por persona',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.button,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),

        // Ajustes de cobro: descuento, propina, dividir
        if (!cargando && pedido != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _BotonAjuste(
                    icon: Icons.percent,
                    label: 'DESCUENTO',
                    activo: _descuento > 0,
                    onTap: procesando ? null : _abrirDescuento,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _BotonAjuste(
                    icon: Icons.savings_outlined,
                    label: 'PROPINA',
                    activo: _propina > 0,
                    onTap: procesando ? null : _abrirPropina,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SelectorDividir(
                    valor: _dividirEn,
                    onCambio: procesando
                        ? null
                        : (n) => setState(() => _dividirEn = n),
                  ),
                ),
              ],
            ),
          ),

        // Botones de cobro
        if (!cargando && pedido != null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'MÉTODO DE PAGO',
                  style: TextStyle(
                    color: AppColors.background,
                    fontSize: 12,
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


// ─── Botón compacto de ajuste de cobro (Descuento / Propina) ────────────────
class _BotonAjuste extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool activo;
  final VoidCallback? onTap;

  const _BotonAjuste({
    required this.icon,
    required this.label,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = activo ? AppColors.button : AppColors.textSecondary;
    return Material(
      color: activo
          ? AppColors.button.withValues(alpha: 0.15)
          : AppColors.background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: activo ? AppColors.button : AppColors.line,
              width: activo ? 1.5 : 0.8,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Selector de "dividir entre N" — calculadora informativa ─────────────────
class _SelectorDividir extends StatelessWidget {
  final int valor;
  final void Function(int)? onCambio;

  const _SelectorDividir({required this.valor, required this.onCambio});

  @override
  Widget build(BuildContext context) {
    final activo = valor > 1;
    final color = activo ? AppColors.button : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: activo
            ? AppColors.button.withValues(alpha: 0.15)
            : AppColors.background,
        border: Border.all(
          color: activo ? AppColors.button : AppColors.line,
          width: activo ? 1.5 : 0.8,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'DIVIDIR',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: (onCambio == null || valor <= 1)
                    ? null
                    : () => onCambio!(valor - 1),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.remove, size: 16, color: color),
                ),
              ),
              SizedBox(
                width: 22,
                child: Text(
                  '$valor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              InkWell(
                onTap: (onCambio == null || valor >= 12)
                    ? null
                    : () => onCambio!(valor + 1),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.add, size: 16, color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
