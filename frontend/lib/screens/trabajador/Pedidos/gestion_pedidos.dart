import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/app_routes.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/core/app_snackbar.dart';
import 'package:frontend/models/mesa_model.dart';
import 'package:frontend/models/pedido_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/trabajador/Pedidos/pedido_domicilio.dart';
import 'package:frontend/screens/trabajador/appbar_trabajador.dart';
import 'package:frontend/screens/trabajador/servicio_trabajador/modificar_comanda.dart';
import 'package:frontend/screens/trabajador/servicio_trabajador/sacar_cuenta.dart';
import 'package:frontend/screens/trabajador/servicio_trabajador/seleccion_mesa.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/mesa_service.dart';
import 'package:frontend/services/pedido_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
// RAÍZ
// ─────────────────────────────────────────────────────────────
class GestionPedidos extends StatefulWidget {
  /// Tab inicial: 0=Activos, 1=Listos, 2=Cobrar.
  /// Se usa cuando entras desde un atajo (ej. "Pedidos listos" en Servicio).
  final int initialTab;

  const GestionPedidos({super.key, this.initialTab = 0});

  @override
  State<GestionPedidos> createState() => _GestionPedidosState();
}

class _GestionPedidosState extends State<GestionPedidos>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Estado compartido de carga
  List<Pedido> _pedidos = [];
  bool _cargando = true;
  String? _error;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _cargarPedidos();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _cargarPedidos(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarPedidos() async {
    final restauranteId =
        context.read<AuthProvider>().usuarioActual?.restauranteId;
    try {
      final todos = await ApiService.obtenerTodosLosPedidos(
        restauranteId: restauranteId,
        estados: ['pendiente', 'preparando', 'listo', 'entregado'],
      );
      if (!mounted) return;
      setState(() {
        _pedidos = todos;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _refrescar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    await _cargarPedidos();
  }

  // ── Filtros por tab ────────────────────────────────────────

  List<Pedido> get _activos => _pedidos
      .where((p) => p.estado == 'pendiente' || p.estado == 'preparando')
      .toList();

  List<Pedido> get _listos =>
      _pedidos.where((p) => p.estado == 'listo').toList();

  // Cobrar solo aplica a pedidos en mesa pendientes de pago: domicilio y
  // recoger se pagan online en el momento del checkout (Stripe/PayPal/wallet)
  // y no necesitan cobro manual del camarero. Una vez pagado, el pedido sale
  // de este tab (es histórico, ya no requiere acción).
  List<Pedido> get _cobrar => _pedidos
      .where((p) =>
          p.estado == 'entregado' &&
          p.tipoEntrega == 'local' &&
          p.estadoPago != 'pagado')
      .toList();

  // ── Acciones ──────────────────────────────────────────────

  Future<void> _marcarEntregado(Pedido pedido) async {
    try {
      await ApiService.actualizarEstadoPedido(
        pedidoId: pedido.id,
        estado: 'entregado',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: const Text(
              'PEDIDO ENTREGADO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
            backgroundColor: AppColors.button,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      await _cargarPedidos();
    } catch (e) {
      if (!mounted) return;
      showAppError(context, 'Error al entregar: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  /// Abre selector de mesas libres y mueve el pedido. Solo para pedidos de
  /// mesa (tipo local). Operativa típica: el grupo se muda de Mesa 4 a 12.
  Future<void> _moverMesa(Pedido pedido) async {
    final restauranteId =
        context.read<AuthProvider>().usuarioActual?.restauranteId;
    final List<Mesa> mesas;
    try {
      mesas = await MesaService.obtenerMesas(restauranteId: restauranteId);
    } catch (e) {
      if (!mounted) return;
      showAppError(
        context,
        'No se pudieron cargar las mesas: ${e.toString().replaceFirst('Exception: ', '')}',
      );
      return;
    }
    if (!mounted) return;
    // Mostramos solo mesas libres y excluimos la actual del pedido.
    final disponibles = mesas
        .where((m) => m.disponible && m.id != pedido.mesaId)
        .toList()
      ..sort((a, b) => a.numero.compareTo(b.numero));

    if (disponibles.isEmpty) {
      showAppInfo(context, 'No hay mesas libres ahora mismo');
      return;
    }

    final mesa = await showDialog<Mesa>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.panel,
        title: Text(
          'Mover de Mesa ${pedido.numeroMesa ?? '-'} a...',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final m in disponibles)
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, m),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.button.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${m.numero}',
                              style: const TextStyle(
                                color: AppColors.button,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Mesa ${m.numero} · ${m.ubicacion} · ${m.capacidad} pax',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
    if (mesa == null || !mounted) return;

    try {
      await PedidoService.moverPedidoAOtraMesa(
        pedidoId: pedido.id,
        nuevaMesaId: mesa.id,
      );
      if (!mounted) return;
      showAppSuccess(context, 'Pedido movido a Mesa ${mesa.numero}');
      await _cargarPedidos();
    } catch (e) {
      if (!mounted) return;
      showAppError(
        context,
        'Error al mover: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  /// Transfiere el pedido a otro camarero (cambio de turno o ayuda mutua).
  /// Carga la lista de camareros activos de la sucursal y deja al actor
  /// elegir el destino. El backend valida permisos y aislamiento.
  Future<void> _transferirPedido(Pedido pedido) async {
    final List<Map<String, dynamic>> camareros;
    try {
      camareros = await PedidoService.listarCamarerosDisponibles();
    } catch (e) {
      if (!mounted) return;
      showAppError(
        context,
        'No se pudo cargar la lista de camareros: ${e.toString().replaceFirst('Exception: ', '')}',
      );
      return;
    }
    if (!mounted) return;
    if (camareros.isEmpty) {
      showAppInfo(context, 'No hay otros camareros disponibles');
      return;
    }

    final destino = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.panel,
        title: const Text(
          'Transferir pedido a...',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in camareros)
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, c),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.button,
                            radius: 16,
                            child: Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (c['nombre'] as String?) ?? 'Sin nombre',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  (c['correo'] as String?) ?? '',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
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
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
    if (destino == null || !mounted) return;

    try {
      await PedidoService.transferirPedido(
        pedidoId: pedido.id,
        nuevoResponsableSub: destino['id'] as String,
      );
      if (!mounted) return;
      showAppSuccess(
        context,
        'Pedido transferido a ${destino['nombre']}',
      );
      await _cargarPedidos();
    } catch (e) {
      if (!mounted) return;
      showAppError(
        context,
        'Error al transferir: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _iniciarCancelacion(Pedido pedido) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => _DialogMotivoCancelacion(pedido: pedido),
    );
    if (motivo == null || !mounted) return;

    try {
      await PedidoService.cancelarPedido(
        pedidoId: pedido.id,
        motivoCancelacion: motivo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: const Text(
              'PEDIDO CANCELADO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      await _cargarPedidos();
    } catch (e) {
      if (!mounted) return;
      showAppError(context, 'Error al cancelar: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const TrabajadorAppBar(title: 'GESTIÓN DE PEDIDOS'),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Bravo restaurante.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
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
          child: SafeArea(
            child: FadeSlideIn(
              child: Column(
              children: [
                // ── TabBar + refresh en el body (bajo el AppBar transparente) ──
                Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: AppColors.button,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        indicatorWeight: 2.5,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                        tabs: [
                          _TabConBadge(label: 'ACTIVOS', count: _activos.length),
                          _TabConBadge(label: 'LISTOS', count: _listos.length),
                          _TabConBadge(label: 'COBRAR', count: _cobrar.length),
                        ],
                      ),
                    ),
                    Semantics(
                      label: 'Actualizar pedidos',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        tooltip: 'Actualizar',
                        onPressed: _refrescar,
                      ),
                    ),
                  ],
                ),
                // ── Contenido de cada tab ──
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _TabActivos(
                        pedidos: _activos,
                        cargando: _cargando,
                        error: _error,
                        onRefresh: _refrescar,
                        onModificar: (p) => Navigator.push(
                          context,
                          AppRoute.slide(ModificarComanda(mesaIdInicial: p.mesaId)),
                        ),
                        onCancelar: _iniciarCancelacion,
                        onMover: _moverMesa,
                        onTransferir: _transferirPedido,
                      ),
                      _TabListos(
                        pedidos: _listos,
                        cargando: _cargando,
                        error: _error,
                        onRefresh: _refrescar,
                        onEntregar: _marcarEntregado,
                      ),
                      _TabCobrar(
                        pedidos: _cobrar,
                        cargando: _cargando,
                        error: _error,
                        onRefresh: _refrescar,
                        onSacarCuenta: (p) => Navigator.push(
                          context,
                          AppRoute.slide(SacarCuenta(mesaIdInicial: p.mesaId)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarBottomSheetCrear(context),
        backgroundColor: AppColors.button,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'CREAR PEDIDO',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  void _mostrarBottomSheetCrear(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _CrearPedidoBottomSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGET AUXILIAR — Tab con badge de conteo
// ─────────────────────────────────────────────────────────────
class _TabConBadge extends StatelessWidget {
  final String label;
  final int count;

  const _TabConBadge({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: AppColors.button,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTTOM SHEET — Crear pedido
// ─────────────────────────────────────────────────────────────
class _CrearPedidoBottomSheet extends StatelessWidget {
  const _CrearPedidoBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'TIPO DE PEDIDO',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Selecciona cómo quieres crear el pedido',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),

          // Opción local
          _OpcionTipoPedido(
            icono: Icons.table_restaurant_outlined,
            titulo: 'Local (mesa)',
            subtitulo: 'Pedido para una mesa del restaurante',
            color: AppColors.button,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                AppRoute.slide(const SeleccionMesa()),
              );
            },
          ),

          const SizedBox(height: 12),

          // Opción domicilio
          _OpcionTipoPedido(
            icono: Icons.delivery_dining_outlined,
            titulo: 'A domicilio',
            subtitulo: 'Pedido para enviar a domicilio',
            color: AppColors.info,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                AppRoute.slide(const PedidoDomicilio()),
              );
            },
          ),

          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}

class _OpcionTipoPedido extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Color color;
  final VoidCallback onTap;

  const _OpcionTipoPedido({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// COMPONENTE REUTILIZABLE — Tarjeta de pedido
// ─────────────────────────────────────────────────────────────
class _PedidoTile extends StatelessWidget {
  final Pedido pedido;
  final String labelAccion;
  final Color colorAccion;
  final VoidCallback onAccion;
  final VoidCallback? onAccionSecundaria;
  final String? labelAccionSecundaria;
  // Acción terciaria opcional (ej. MOVER mesa). Se renderiza como outlined
  // pequeño, sin color destructivo, antes de la secundaria.
  final VoidCallback? onAccionTerciaria;
  final String? labelAccionTerciaria;
  // Acción cuarta opcional (ej. TRANSFERIR pedido). Mismo estilo que la
  // terciaria; útil para acciones de cambio de turno / ayuda mutua.
  final VoidCallback? onAccionCuarta;
  final String? labelAccionCuarta;

  const _PedidoTile({
    required this.pedido,
    required this.labelAccion,
    required this.colorAccion,
    required this.onAccion,
    this.onAccionSecundaria,
    this.labelAccionSecundaria,
    this.onAccionTerciaria,
    this.labelAccionTerciaria,
    this.onAccionCuarta,
    this.labelAccionCuarta,
  });

  String get _etiquetaUbicacion {
    switch (pedido.tipoEntrega) {
      case 'local':
        return 'Mesa ${pedido.numeroMesa ?? '-'}';
      case 'domicilio':
        return 'Domicilio';
      case 'recoger':
        return 'Para recoger';
      default:
        return pedido.tipoEntrega;
    }
  }

  IconData get _iconoUbicacion {
    switch (pedido.tipoEntrega) {
      case 'local':
        return Icons.table_restaurant_outlined;
      case 'domicilio':
        return Icons.delivery_dining_outlined;
      case 'recoger':
        return Icons.shopping_bag_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  Color get _colorEstado {
    switch (pedido.estado) {
      case 'pendiente':
        return AppColors.surfacePending;
      case 'preparando':
        return AppColors.button;
      case 'listo':
        return AppColors.info;
      case 'entregado':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  String get _labelEstado {
    switch (pedido.estado) {
      case 'pendiente':
        return 'PENDIENTE';
      case 'preparando':
        return 'EN PREP.';
      case 'listo':
        return 'LISTO';
      case 'entregado':
        return 'ENTREGADO';
      default:
        return pedido.estado.toUpperCase();
    }
  }

  String _hora(String fecha) {
    try {
      final dt = DateTime.parse(fecha);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  /// Tiempo transcurrido desde que se creó el pedido. Útil para anticipar
  /// rotación de mesas y detectar pedidos que llevan demasiado tiempo en
  /// cocina. Se actualiza con cada poll (30s) — no usamos timers internos.
  String _tiempoEnMesa(String fecha) {
    try {
      final dt = DateTime.parse(fecha);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'recién';
      if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      return m == 0 ? 'hace ${h}h' : 'hace ${h}h ${m}min';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila superior: estado + ubicación + hora
            Row(
              children: [
                // Chip de estado
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _colorEstado.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _colorEstado.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    _labelEstado,
                    style: TextStyle(
                      color: _colorEstado,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(_iconoUbicacion,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _etiquetaUbicacion,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _hora(pedido.fecha),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _tiempoEnMesa(pedido.fecha),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Resumen detallado: lista de items del pedido para que el
            // camarero sepa qué tiene que llevar / cobrar sin abrir más.
            if (pedido.productos.isNotEmpty) ...[
              for (final p in pedido.productos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '×${p.cantidad}',
                          style: const TextStyle(
                            color: AppColors.button,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.nombre,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (p.sin.isNotEmpty)
                              Text(
                                'sin ${p.sin.join(', ')}',
                                style: TextStyle(
                                  color: AppColors.error.withValues(alpha: 0.85),
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
            ],
            // Fila inferior: total + botón acción
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${pedido.productos.length} plato${pedido.productos.length != 1 ? 's' : ''} · ${pedido.total.toStringAsFixed(2)} €',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Acción terciaria (mover mesa) — outlined neutral
                if (onAccionTerciaria != null && labelAccionTerciaria != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: OutlinedButton(
                      onPressed: onAccionTerciaria,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(
                          color: AppColors.textSecondary,
                          width: 0.8,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        labelAccionTerciaria!,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                // Acción cuarta (transferir pedido) — outlined neutral
                if (onAccionCuarta != null && labelAccionCuarta != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: OutlinedButton(
                      onPressed: onAccionCuarta,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(
                          color: AppColors.textSecondary,
                          width: 0.8,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        labelAccionCuarta!,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                // Acción secundaria (cancelar)
                if (onAccionSecundaria != null && labelAccionSecundaria != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: OutlinedButton(
                      onPressed: onAccionSecundaria,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(
                            color: AppColors.error, width: 0.8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        labelAccionSecundaria!,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                // Acción principal
                ElevatedButton(
                  onPressed: onAccion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorAccion,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    labelAccion,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGET AUXILIAR — Estado vacío/error/loading uniforme por tab
// ─────────────────────────────────────────────────────────────
class _EstadoTab extends StatelessWidget {
  final bool cargando;
  final String? error;
  final bool estaVacio;
  final String mensajeVacio;
  final VoidCallback onReintentar;

  const _EstadoTab({
    required this.cargando,
    required this.error,
    required this.estaVacio,
    required this.mensajeVacio,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.button,
          strokeWidth: 2.5,
        ),
      );
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onReintentar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'REINTENTAR',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (estaVacio) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 52,
              color: AppColors.textSecondary.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 14),
            Text(
              mensajeVacio,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────
// TAB — ACTIVOS
// ─────────────────────────────────────────────────────────────
class _TabActivos extends StatelessWidget {
  final List<Pedido> pedidos;
  final bool cargando;
  final String? error;
  final Future<void> Function() onRefresh;
  final void Function(Pedido) onModificar;
  final Future<void> Function(Pedido) onCancelar;
  final Future<void> Function(Pedido) onMover;
  final Future<void> Function(Pedido) onTransferir;

  const _TabActivos({
    required this.pedidos,
    required this.cargando,
    required this.error,
    required this.onRefresh,
    required this.onModificar,
    required this.onCancelar,
    required this.onMover,
    required this.onTransferir,
  });

  @override
  Widget build(BuildContext context) {
    final mostrarEstado = cargando || error != null || pedidos.isEmpty;
    if (mostrarEstado) {
      return _EstadoTab(
        cargando: cargando,
        error: error,
        estaVacio: pedidos.isEmpty,
        mensajeVacio: 'Sin pedidos activos',
        onReintentar: onRefresh,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.button,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: pedidos.length,
        itemBuilder: (_, i) {
          final p = pedidos[i];
          // MODIFICAR solo tiene sentido en pedidos de mesa: el camarero
          // puede añadir platos en sala. Los pedidos de domicilio/recoger
          // ya están cerrados (cliente pagó online) y solo se pueden cancelar.
          final esLocal = p.tipoEntrega == 'local';
          return _PedidoTile(
            pedido: p,
            labelAccion: esLocal ? 'MODIFICAR' : 'CANCELAR',
            colorAccion: esLocal ? AppColors.button : AppColors.error,
            onAccion: () =>
                esLocal ? onModificar(p) : onCancelar(p),
            labelAccionSecundaria: esLocal ? 'CANCELAR' : null,
            onAccionSecundaria: esLocal ? () => onCancelar(p) : null,
            // MOVER MESA: solo para pedidos de mesa que aún no se han cobrado.
            // En domicilio/recoger no aplica.
            labelAccionTerciaria: esLocal ? 'MOVER' : null,
            onAccionTerciaria: esLocal ? () => onMover(p) : null,
            // TRANSFERIR el pedido a otro camarero (cambio de turno).
            // Aplica también a pedidos no-mesa (domicilio/recoger pueden
            // pasar a otro camarero), así que lo dejamos siempre disponible.
            labelAccionCuarta: 'TRANSF.',
            onAccionCuarta: () => onTransferir(p),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB — LISTOS
// ─────────────────────────────────────────────────────────────
class _TabListos extends StatelessWidget {
  final List<Pedido> pedidos;
  final bool cargando;
  final String? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Pedido) onEntregar;

  const _TabListos({
    required this.pedidos,
    required this.cargando,
    required this.error,
    required this.onRefresh,
    required this.onEntregar,
  });

  @override
  Widget build(BuildContext context) {
    final mostrarEstado = cargando || error != null || pedidos.isEmpty;
    if (mostrarEstado) {
      return _EstadoTab(
        cargando: cargando,
        error: error,
        estaVacio: pedidos.isEmpty,
        mensajeVacio: 'Sin pedidos listos',
        onReintentar: onRefresh,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.button,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: pedidos.length,
        itemBuilder: (_, i) => _PedidoTile(
          pedido: pedidos[i],
          labelAccion: 'ENTREGAR',
          colorAccion: AppColors.info,
          onAccion: () => onEntregar(pedidos[i]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB — COBRAR
// ─────────────────────────────────────────────────────────────
class _TabCobrar extends StatelessWidget {
  final List<Pedido> pedidos;
  final bool cargando;
  final String? error;
  final Future<void> Function() onRefresh;
  final void Function(Pedido) onSacarCuenta;

  const _TabCobrar({
    required this.pedidos,
    required this.cargando,
    required this.error,
    required this.onRefresh,
    required this.onSacarCuenta,
  });

  @override
  Widget build(BuildContext context) {
    final mostrarEstado = cargando || error != null || pedidos.isEmpty;
    if (mostrarEstado) {
      return _EstadoTab(
        cargando: cargando,
        error: error,
        estaVacio: pedidos.isEmpty,
        mensajeVacio: 'Sin pedidos pendientes de cobro',
        onReintentar: onRefresh,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.button,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: pedidos.length,
        itemBuilder: (_, i) => _PedidoTile(
          pedido: pedidos[i],
          labelAccion: 'SACAR CUENTA',
          colorAccion: AppColors.success,
          onAccion: () => onSacarCuenta(pedidos[i]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DIALOG — Motivo de cancelación (mantenido del código original)
// ─────────────────────────────────────────────────────────────
class _DialogMotivoCancelacion extends StatefulWidget {
  final Pedido pedido;

  const _DialogMotivoCancelacion({required this.pedido});

  @override
  State<_DialogMotivoCancelacion> createState() =>
      _DialogMotivoCancelacionState();
}

class _DialogMotivoCancelacionState extends State<_DialogMotivoCancelacion> {
  final _ctrl = TextEditingController();
  bool _puedeConfirmar = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _etiqueta {
    switch (widget.pedido.tipoEntrega) {
      case 'local':
        return 'Mesa ${widget.pedido.numeroMesa ?? '-'}';
      case 'domicilio':
        return 'Domicilio';
      case 'recoger':
        return 'Para recoger';
      default:
        return widget.pedido.tipoEntrega;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MOTIVO DE CANCELACIÓN',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _etiqueta,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _ctrl,
              maxLines: 4,
              maxLength: 200,
              onChanged: (v) {
                final tiene = v.trim().isNotEmpty;
                if (tiene != _puedeConfirmar) {
                  setState(() => _puedeConfirmar = tiene);
                }
              },
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Describe el motivo de la cancelación…',
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.button, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.line),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'VOLVER',
                      style: TextStyle(fontSize: 11, letterSpacing: 1.2),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _puedeConfirmar
                        ? () => Navigator.pop(context, _ctrl.text.trim())
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.error.withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'CONFIRMAR',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
