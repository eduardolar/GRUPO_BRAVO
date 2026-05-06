import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/pedido_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/server_time_service.dart';

// ── Constantes ───────────────────────────────────────────────────────────

const List<String> _kEstados = ['pendiente', 'preparando', 'listo'];
const _kSonidoNuevoPedido = 'sounds/new_order.mp3';
const _kPollInterval = Duration(seconds: 30);
// Fallback de fluidez visual: refresca cronómetros cuando el poll falla.
// No recarga datos del backend; ese trabajo lo hace _pollTimer.
const _kTickInterval = Duration(seconds: 60);
const _kLongPressDelay = Duration(milliseconds: 280);
const _kAnimDuration = Duration(milliseconds: 180);
const _kRadius = BorderRadius.all(Radius.circular(12));

const double _kColMinWidth = 220;
const double _kFeedbackWidth = 190;

const Color _kVerde = Color(0xFF16A34A);
const Color _kAmbar = Color(0xFFD97706);
const Color _kNaranja = Color(0xFFEA580C);
const Color _kAzul = Color(0xFF2563EB);
const Color _kMarron = Color(0xFFB45309);

// ── Typedefs ─────────────────────────────────────────────────────────────

typedef _MoverEstadoFn = Future<void> Function(Pedido pedido, String estado);
typedef _ToggleItemFn = Future<void> Function(Pedido pedido, int itemIdx);
typedef _ItemHechoCheckFn = bool Function(Pedido pedido, int itemIdx);

// ── Helpers ──────────────────────────────────────────────────────────────

String _labelEstado(String e) {
  switch (e) {
    case 'pendiente':
      return 'Pendiente';
    case 'preparando':
      return 'En cocina';
    case 'listo':
      return 'Listo';
    default:
      return e;
  }
}

Color _colorEstado(String e) {
  switch (e) {
    case 'preparando':
      return AppColors.button;
    case 'listo':
      return _kAzul;
    default:
      return _kMarron;
  }
}

IconData _iconoEstado(String e) {
  switch (e) {
    case 'preparando':
      return Icons.local_fire_department_outlined;
    case 'listo':
      return Icons.check_circle_outline;
    default:
      return Icons.pending_outlined;
  }
}

({String etiqueta, IconData icono}) _entregaInfo(
  String tipoEntrega,
  int? numeroMesa,
) {
  switch (tipoEntrega) {
    case 'local':
      return (
        etiqueta: 'Mesa ${numeroMesa ?? '-'}',
        icono: Icons.table_restaurant_outlined,
      );
    case 'domicilio':
      return (etiqueta: 'A domicilio', icono: Icons.delivery_dining_outlined);
    case 'recoger':
      return (etiqueta: 'Para recoger', icono: Icons.shopping_bag_outlined);
    default:
      return (etiqueta: tipoEntrega, icono: Icons.receipt_long_outlined);
  }
}

/// Minutos transcurridos desde [fechaIso] según la hora del servidor.
/// Devuelve `-1` si la fecha es inválida.
int _minutosDesde(String fechaIso) {
  try {
    final dt = DateTime.parse(fechaIso);
    return ServerTimeService.instance.now.difference(dt).inMinutes;
  } catch (_) {
    return -1;
  }
}

Color _colorTiempo(int minutos) {
  if (minutos < 0) return AppColors.textSecondary;
  if (minutos < 5) return _kVerde;
  if (minutos < 10) return _kAmbar;
  if (minutos < 15) return _kNaranja;
  return AppColors.error;
}

String _formatoTiempo(int minutos) {
  if (minutos < 0) return '—';
  if (minutos < 60) return '${minutos}m';
  final h = minutos ~/ 60;
  final m = minutos % 60;
  return '${h}h ${m}m';
}

String _hora(String fechaIso) {
  try {
    final dt = DateTime.parse(fechaIso);
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}

// ── Pantalla ─────────────────────────────────────────────────────────────

class PedidosCocinaScreen extends StatefulWidget {
  const PedidosCocinaScreen({super.key});

  @override
  State<PedidosCocinaScreen> createState() => _PedidosCocinaScreenState();
}

class _PedidosCocinaScreenState extends State<PedidosCocinaScreen> {
  List<Pedido> _pedidos = [];
  bool _cargando = true;
  bool _primeraCarga = true;
  // Cocinero sin restaurante asignado: no cargamos pedidos para no mezclar
  // los de distintas sucursales. Mostramos un mensaje en el body.
  bool _sinSucursal = false;
  // Evita que dos cargas se solapen (poll del timer + refresh manual). Sin
  // esta guarda, la segunda llamada borra los _estadoOverride/_itemHechoOverride
  // optimistas que el cocinero acaba de pulsar y se ve un "flicker" en la UI.
  bool _pollEnCurso = false;

  Timer? _pollTimer;
  Timer? _tickTimer;
  final AudioPlayer _audio = AudioPlayer();

  final Set<String> _actualizando = {};
  final Map<String, String> _estadoOverride = {};
  // Override optimista de items hechos: {pedidoId: {itemIdx: hecho}}
  final Map<String, Map<int, bool>> _itemHechoOverride = {};
  // IDs ya vistos (para detectar entradas nuevas y sonar). Se purga en cada
  // poll para mantener solo los activos.
  final Set<String> _idsVistos = {};

  // Cada N polls resincronizamos la hora del servidor para corregir deriva.
  static const int _kSyncCadaNPolls = 5;
  int _pollsDesdeUltimaSync = 0;

  @override
  void initState() {
    super.initState();
    _audio.setReleaseMode(ReleaseMode.stop);
    // Sincronizamos hora del servidor antes del primer paint para que los
    // cronómetros muestren un valor correcto desde el principio.
    ServerTimeService.instance.sincronizar().then((_) {
      if (mounted) setState(() {});
    });
    _cargarPedidos();
    _pollTimer = Timer.periodic(_kPollInterval, (_) => _cargarPedidos());
    // Fallback cada 60 s: avanza cronómetros si el poll falla; no toca backend.
    _tickTimer = Timer.periodic(_kTickInterval, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    _audio.dispose();
    super.dispose();
  }

  String _estadoEfectivo(Pedido p) => _estadoOverride[p.id] ?? p.estado;

  bool _itemHechoEfectivo(Pedido p, int idx) {
    final override = _itemHechoOverride[p.id]?[idx];
    if (override != null) return override;
    if (idx < p.productos.length) return p.productos[idx].hecho;
    return false;
  }

  Future<void> _reproducirAlerta() async {
    try {
      await _audio.stop();
      await _audio.play(AssetSource(_kSonidoNuevoPedido));
    } catch (e) {
      debugPrint('No se pudo reproducir alerta de pedido: $e');
    }
  }

  void _showSnack(String mensaje, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: error ? AppColors.error : AppColors.button,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: _kRadius),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
  }

  Future<void> _cargarPedidos() async {
    // Guarda contra cargas solapadas: si hay una en curso, ignoramos esta.
    // Sin esta guarda, un refresh manual mientras corre el poll del timer
    // produce dos respuestas que pisan los overrides optimistas.
    if (_pollEnCurso) return;
    _pollEnCurso = true;
    try {
      // Resincronizar offset con servidor cada N polls para corregir deriva.
      _pollsDesdeUltimaSync++;
      if (_pollsDesdeUltimaSync >= _kSyncCadaNPolls) {
        _pollsDesdeUltimaSync = 0;
        // Sin await: que se resuelva en paralelo sin bloquear el poll.
        ServerTimeService.instance.sincronizar();
      }

      final restauranteId = context
          .read<AuthProvider>()
          .usuarioActual
          ?.restauranteId;

      // Sin sucursal asignada no podemos saber qué pedidos pertenecen a este
      // cocinero. En lugar de traer todos los pedidos del sistema (lo que
      // mezclaría sucursales y permitiría a dos cocineros pelearse por el
      // mismo pedido), abortamos y mostramos un mensaje claro.
      if (restauranteId == null || restauranteId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _sinSucursal = true;
          _cargando = false;
          _pedidos = [];
        });
        return;
      }
      if (_sinSucursal) {
        // Por si el restauranteId aparece tras un cambio de sesión.
        _sinSucursal = false;
      }

      // El backend filtra por estados en servidor; evitamos traer histórico
      // completo (entregado/cancelado) en restaurantes con mucho volumen.
      final activos = (await ApiService.obtenerTodosLosPedidos(
        restauranteId: restauranteId,
        estados: _kEstados.toList(),
      ))..sort((a, b) => a.fecha.compareTo(b.fecha));

      // Detectar nuevos pedidos en estado pendiente. Solo después de la
      // primera carga, para no sonar al abrir la pantalla con histórico.
      final idsActivos = activos.map((p) => p.id).toSet();
      final nuevosPendientes = activos
          .where((p) => p.estado == 'pendiente' && !_idsVistos.contains(p.id))
          .map((p) => p.id)
          .toSet();

      if (!mounted) return;
      setState(() {
        _pedidos = activos;
        _cargando = false;
        _estadoOverride.clear();
        // Purgar overrides e IDs de pedidos que ya no están activos.
        _itemHechoOverride.removeWhere((id, _) => !idsActivos.contains(id));
        _idsVistos
          ..removeWhere((id) => !idsActivos.contains(id))
          ..addAll(idsActivos);
      });

      if (!_primeraCarga && nuevosPendientes.isNotEmpty) {
        _reproducirAlerta();
      }
      _primeraCarga = false;
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      // Solo notificamos en la primera carga: durante el polling normal,
      // un fallo puntual no debería saturar al cocinero con SnackBars.
      if (_primeraCarga) {
        _showSnack('No se pudieron cargar los pedidos: $e');
        _primeraCarga = false;
      } else {
        debugPrint('pedidos_cocina poll fallido: $e');
      }
    } finally {
      _pollEnCurso = false;
    }
  }

  Future<void> _cambiarEstado(Pedido pedido, String nuevoEstado) async {
    if (_actualizando.contains(pedido.id)) return;
    if (_estadoEfectivo(pedido) == nuevoEstado) return;
    setState(() {
      _actualizando.add(pedido.id);
      _estadoOverride[pedido.id] = nuevoEstado;
    });
    try {
      await ApiService.actualizarEstadoPedido(
        pedidoId: pedido.id,
        estado: nuevoEstado,
      );
      await _cargarPedidos();
    } catch (e) {
      if (!mounted) return;
      setState(() => _estadoOverride.remove(pedido.id));
      _showSnack('Error al mover pedido: $e');
    } finally {
      if (mounted) setState(() => _actualizando.remove(pedido.id));
    }
  }

  Future<void> _toggleItemHecho(Pedido pedido, int itemIdx) async {
    final actual = _itemHechoEfectivo(pedido, itemIdx);
    final nuevo = !actual;
    setState(() {
      _itemHechoOverride.putIfAbsent(pedido.id, () => {})[itemIdx] = nuevo;
    });
    try {
      final res = await ApiService.marcarItemHecho(
        pedidoId: pedido.id,
        itemIndex: itemIdx,
        hecho: nuevo,
      );
      if (res['todosHechos'] == true) {
        await _cargarPedidos();
      }
    } catch (e) {
      if (!mounted) return;
      // Revertir override.
      setState(() {
        _itemHechoOverride[pedido.id]?.remove(itemIdx);
        if (_itemHechoOverride[pedido.id]?.isEmpty ?? false) {
          _itemHechoOverride.remove(pedido.id);
        }
      });
      _showSnack('Error al marcar item: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PEDIDOS ACTIVOS',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                fontSize: 17,
              ),
            ),
            if (!_cargando && _pedidos.isNotEmpty) ...[
              const SizedBox(width: 10),
              _BadgeContador(count: _pedidos.length),
            ],
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.button),
              tooltip: 'Actualizar',
              onPressed: () {
                setState(() => _cargando = true);
                _cargarPedidos();
              },
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.line),
        ),
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.button),
            )
          : _sinSucursal
              ? const _SinSucursalView()
              : _buildKanban(),
    );
  }

  Widget _buildKanban() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        const padding = 12.0;
        final available = constraints.maxWidth - padding * 2 - gap * 2;
        final colWidth = max(available / 3, _kColMinWidth);
        final totalWidth = colWidth * 3 + gap * 2 + padding * 2;

        final board = SizedBox(
          width: totalWidth,
          height: constraints.maxHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: padding,
              vertical: 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < _kEstados.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  _KanbanColumn(
                    width: colWidth,
                    height: constraints.maxHeight - 24,
                    estado: _kEstados[i],
                    pedidos: _pedidos
                        .where((p) => _estadoEfectivo(p) == _kEstados[i])
                        .toList(),
                    actualizando: _actualizando,
                    onMover: _cambiarEstado,
                    onToggleItem: _toggleItemHecho,
                    isItemHecho: _itemHechoEfectivo,
                  ),
                ],
              ],
            ),
          ),
        );

        if (totalWidth > constraints.maxWidth) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: board,
          );
        }
        return board;
      },
    );
  }
}

// ── Badge contador en AppBar ─────────────────────────────────────────────

class _BadgeContador extends StatelessWidget {
  final int count;
  const _BadgeContador({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.button.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.button.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppColors.button,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ── COLUMNA KANBAN ───────────────────────────────────────────────────────

class _KanbanColumn extends StatelessWidget {
  final double width;
  final double height;
  final String estado;
  final List<Pedido> pedidos;
  final Set<String> actualizando;
  final _MoverEstadoFn onMover;
  final _ToggleItemFn onToggleItem;
  final _ItemHechoCheckFn isItemHecho;

  const _KanbanColumn({
    required this.width,
    required this.height,
    required this.estado,
    required this.pedidos,
    required this.actualizando,
    required this.onMover,
    required this.onToggleItem,
    required this.isItemHecho,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorEstado(estado);
    return DragTarget<Pedido>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => onMover(d.data, estado),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: _kAnimDuration,
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: hovering
                ? color.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hovering ? color.withValues(alpha: 0.45) : AppColors.line,
              width: hovering ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              _buildHeader(color),
              Expanded(
                child: pedidos.isEmpty
                    ? _buildEmpty(color)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                        itemCount: pedidos.length,
                        itemBuilder: (_, i) {
                          final p = pedidos[i];
                          return RepaintBoundary(
                            key: ValueKey('cocina-card-${p.id}'),
                            child: _DraggableCard(
                              pedido: p,
                              actualizando: actualizando.contains(p.id),
                              currentEstado: estado,
                              onMover: onMover,
                              onToggleItem: onToggleItem,
                              isItemHecho: isItemHecho,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1.5),
            ),
            child: Icon(_iconoEstado(estado), color: color, size: 15),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _labelEstado(estado).toUpperCase(),
              style: TextStyle(
                fontFamily: 'Playfair Display',
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${pedidos.length}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _iconoEstado(estado),
            color: color.withValues(alpha: 0.15),
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            'Sin pedidos',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.35),
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── WRAPPER DRAGGABLE ────────────────────────────────────────────────────

class _DraggableCard extends StatelessWidget {
  final Pedido pedido;
  final bool actualizando;
  final String currentEstado;
  final _MoverEstadoFn onMover;
  final _ToggleItemFn onToggleItem;
  final _ItemHechoCheckFn isItemHecho;

  const _DraggableCard({
    required this.pedido,
    required this.actualizando,
    required this.currentEstado,
    required this.onMover,
    required this.onToggleItem,
    required this.isItemHecho,
  });

  @override
  Widget build(BuildContext context) {
    final card = _PedidoCard(
      pedido: pedido,
      currentEstado: currentEstado,
      onMover: onMover,
      onToggleItem: onToggleItem,
      isItemHecho: isItemHecho,
      loading: actualizando,
    );

    if (actualizando) return card;

    return LongPressDraggable<Pedido>(
      data: pedido,
      delay: _kLongPressDelay,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.88,
          child: SizedBox(
            width: _kFeedbackWidth,
            child: _PedidoCard(
              pedido: pedido,
              currentEstado: currentEstado,
              onMover: onMover,
              onToggleItem: onToggleItem,
              isItemHecho: isItemHecho,
              compact: true,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: card),
      child: card,
    );
  }
}

// ── TARJETA ──────────────────────────────────────────────────────────────

class _PedidoCard extends StatelessWidget {
  final Pedido pedido;
  final String currentEstado;
  final _MoverEstadoFn onMover;
  final _ToggleItemFn onToggleItem;
  final _ItemHechoCheckFn isItemHecho;
  final bool compact;
  final bool loading;

  const _PedidoCard({
    required this.pedido,
    required this.currentEstado,
    required this.onMover,
    required this.onToggleItem,
    required this.isItemHecho,
    this.compact = false,
    this.loading = false,
  });

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
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCabecera(),
              if (!compact) ...[
                const Divider(height: 1, color: AppColors.line),
                _buildProductos(),
                if (pedido.notas != null && pedido.notas!.isNotEmpty)
                  _buildNotas(),
                const Divider(height: 1, color: AppColors.line),
                _buildBotones(),
              ],
            ],
          ),
          if (loading)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: AppColors.panel.withValues(alpha: 0.75),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: AppColors.button,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCabecera() {
    final info = _entregaInfo(pedido.tipoEntrega, pedido.numeroMesa);
    final minutos = _minutosDesde(pedido.fecha);
    final colorTiempo = _colorTiempo(minutos);
    return Padding(
      padding: const EdgeInsets.all(11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1.5),
            ),
            child: Icon(info.icono, color: AppColors.gold, size: 16),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.etiqueta,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _hora(pedido.fecha),
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _ChipCronometro(color: colorTiempo, texto: _formatoTiempo(minutos)),
          if (!compact) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Mantén pulsado para arrastrar',
              child: Icon(
                Icons.drag_indicator,
                color: AppColors.textSecondary.withValues(alpha: 0.22),
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductos() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < pedido.productos.length; i++)
            _itemRow(i, pedido.productos[i]),
        ],
      ),
    );
  }

  Widget _itemRow(int idx, ProductoPedido p) {
    final hecho = isItemHecho(pedido, idx);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => onToggleItem(pedido, idx),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: hecho,
                  onChanged: (_) => onToggleItem(pedido, idx),
                  activeColor: AppColors.button,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  '${p.cantidad}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nombre.isNotEmpty ? p.nombre : 'Producto',
                      style: TextStyle(
                        color: hecho
                            ? AppColors.textSecondary.withValues(alpha: 0.6)
                            : AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        decoration: hecho
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: AppColors.textSecondary.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    if (p.sin.isNotEmpty)
                      Text(
                        'Sin: ${p.sin.join(', ')}',
                        style: TextStyle(
                          color: AppColors.error.withValues(alpha: 0.85),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 0, 11, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.notes_outlined,
              size: 12,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                pedido.notas!,
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotones() {
    final idx = _kEstados.indexOf(currentEstado);
    final hasPrev = idx > 0;
    final hasNext = idx < _kEstados.length - 1;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          if (hasPrev) ...[
            Expanded(
              child: _Boton(
                icon: Icons.chevron_left,
                label: _labelEstado(_kEstados[idx - 1]),
                onPressed: () => onMover(pedido, _kEstados[idx - 1]),
                primary: false,
                iconLeft: true,
              ),
            ),
            if (hasNext) const SizedBox(width: 8),
          ],
          if (hasNext)
            Expanded(
              child: _Boton(
                icon: Icons.chevron_right,
                label: _labelEstado(_kEstados[idx + 1]),
                onPressed: () => onMover(pedido, _kEstados[idx + 1]),
                primary: true,
                iconLeft: false,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Chip cronómetro ──────────────────────────────────────────────────────

class _ChipCronometro extends StatelessWidget {
  final Color color;
  final String texto;
  const _ChipCronometro({required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Botón ────────────────────────────────────────────────────────────────

class _Boton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final bool iconLeft;

  const _Boton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.primary,
    required this.iconLeft,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary ? AppColors.button : AppColors.panel,
          foregroundColor: primary ? Colors.white : AppColors.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.gold, width: 1.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconLeft) ...[Icon(icon, size: 13), const SizedBox(width: 3)],
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!iconLeft) ...[const SizedBox(width: 3), Icon(icon, size: 13)],
          ],
        ),
      ),
    );
  }
}

// ── Vista cuando el cocinero no tiene sucursal asignada ──────────────────

class _SinSucursalView extends StatelessWidget {
  const _SinSucursalView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 18),
            const Text(
              'Sin sucursal asignada',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Playfair Display',
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tu cuenta no tiene un restaurante asignado, por lo que no se '
              'pueden mostrar los pedidos de cocina. Pide al administrador '
              'que te asigne a una sucursal.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
