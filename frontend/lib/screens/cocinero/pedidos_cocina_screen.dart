import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/app_snackbar.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/pedido_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/server_time_service.dart';
import 'package:frontend/screens/cocinero/cocina_helpers.dart';

// ── Constantes ───────────────────────────────────────────────────────────

const List<String> _kEstados = ['pendiente', 'preparando', 'listo'];
const _kSonidoNuevoPedido = 'sounds/new_order.mp3';
// Polling adaptativo: rápido cuando la pantalla está activa (cocinero
// pendiente del kanban), lento en background, máximo en back-off por errores.
const _kPollIntervalActivo = Duration(seconds: 10);
const _kPollIntervalBackground = Duration(seconds: 30);
const _kPollIntervalMax = Duration(seconds: 60);
// Fallback de fluidez visual: refresca cronómetros cuando el poll falla.
const _kTickInterval = Duration(seconds: 60);
const _kLongPressDelay = Duration(milliseconds: 280);
const _kAnimDuration = Duration(milliseconds: 180);

const double _kColMinWidth = 220;
const double _kFeedbackWidth = 190;

// ── Typedefs ─────────────────────────────────────────────────────────────

typedef _MoverEstadoFn = Future<void> Function(Pedido pedido, String estado);
typedef _ToggleItemFn = Future<void> Function(Pedido pedido, int itemIdx);
typedef _ItemHechoCheckFn = bool Function(Pedido pedido, int itemIdx);

// ── Pantalla ─────────────────────────────────────────────────────────────

class PedidosCocinaScreen extends StatefulWidget {
  const PedidosCocinaScreen({super.key});

  @override
  State<PedidosCocinaScreen> createState() => _PedidosCocinaScreenState();
}

class _PedidosCocinaScreenState extends State<PedidosCocinaScreen>
    with WidgetsBindingObserver {
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

  // Polling adaptativo (opción A).
  bool _pausado = false;
  bool _enPrimerPlano = true;
  int _fallosConsecutivos = 0;

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

  // Indicador "última actualización" (cambio E)
  DateTime? _ultimoExito;

  // Cada N polls resincronizamos la hora del servidor para corregir deriva.
  static const int _kSyncCadaNPolls = 5;
  int _pollsDesdeUltimaSync = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio.setReleaseMode(ReleaseMode.stop);
    // Sincronizamos hora del servidor antes del primer paint para que los
    // cronómetros muestren un valor correcto desde el principio.
    ServerTimeService.instance.sincronizar().then((_) {
      if (mounted) setState(() {});
    });
    _cargarPedidos();
    _reprogramarPoll();
    // Fallback cada 60 s: avanza cronómetros si el poll falla; no toca backend.
    _tickTimer = Timer.periodic(_kTickInterval, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    _audio.dispose();
    super.dispose();
  }

  /// Intervalo actual del poll: 10 s en primer plano, 30 s en background, con
  /// back-off exponencial hasta 60 s tras fallos consecutivos.
  Duration _intervaloActual() {
    final base = _enPrimerPlano
        ? _kPollIntervalActivo
        : _kPollIntervalBackground;
    if (_fallosConsecutivos == 0) return base;
    final factor = 1 << _fallosConsecutivos.clamp(0, 3);
    final segundos = base.inSeconds * factor;
    return segundos > _kPollIntervalMax.inSeconds
        ? _kPollIntervalMax
        : Duration(seconds: segundos);
  }

  /// Cancela y vuelve a programar el timer con el intervalo actual. Si la
  /// pantalla está pausada no programa nada.
  void _reprogramarPoll() {
    _pollTimer?.cancel();
    if (_pausado) return;
    _pollTimer = Timer.periodic(
      _intervaloActual(),
      (_) => _cargarPedidos(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _enPrimerPlano) return;
    _enPrimerPlano = foreground;
    _reprogramarPoll();
    // Al volver al primer plano refrescamos inmediatamente.
    if (foreground) _cargarPedidos();
  }

  void _togglePausa() {
    setState(() => _pausado = !_pausado);
    _reprogramarPoll();
    if (!_pausado) _cargarPedidos();
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

  // Cambio C: _showSnack eliminado; se usa handleApiError / showAppError /
  // showAppSuccess directamente en cada llamada.

  Future<void> _cargarPedidos() async {
    // Guarda contra cargas solapadas: si hay una en curso, ignoramos esta.
    if (_pollEnCurso) return;
    _pollEnCurso = true;
    try {
      // Resincronizar offset con servidor cada N polls para corregir deriva.
      _pollsDesdeUltimaSync++;
      if (_pollsDesdeUltimaSync >= _kSyncCadaNPolls) {
        _pollsDesdeUltimaSync = 0;
        ServerTimeService.instance.sincronizar();
      }

      final restauranteId = context
          .read<AuthProvider>()
          .usuarioActual
          ?.restauranteId;

      // Sin sucursal asignada no podemos saber qué pedidos pertenecen a este
      // cocinero. Mostramos un mensaje claro.
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
        _sinSucursal = false;
      }

      final activos = (await ApiService.obtenerTodosLosPedidos(
        restauranteId: restauranteId,
        estados: _kEstados.toList(),
      ))..sort((a, b) => a.fecha.compareTo(b.fecha));

      final idsActivos = activos.map((p) => p.id).toSet();
      final nuevosPendientes = activos
          .where((p) => p.estado == 'pendiente' && !_idsVistos.contains(p.id))
          .map((p) => p.id)
          .toSet();

      if (!mounted) return;
      final huboFallos = _fallosConsecutivos > 0;
      setState(() {
        _pedidos = activos;
        _cargando = false;
        _estadoOverride.clear();
        _itemHechoOverride.removeWhere((id, _) => !idsActivos.contains(id));
        _idsVistos
          ..removeWhere((id) => !idsActivos.contains(id))
          ..addAll(idsActivos);
        // Cambio E: registrar timestamp del último poll exitoso
        _ultimoExito = DateTime.now();
        _fallosConsecutivos = 0;
      });
      // Si el back-off había alargado el intervalo, restauramos el normal.
      if (huboFallos) _reprogramarPoll();

      if (!_primeraCarga && nuevosPendientes.isNotEmpty) {
        _reproducirAlerta();
      }
      _primeraCarga = false;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _fallosConsecutivos++;
      });
      // Reprogramar con back-off para no saturar al backend si está caído.
      _reprogramarPoll();
      // Solo notificamos en la primera carga para no saturar al cocinero.
      if (_primeraCarga) {
        // Cambio C: usar handleApiError en lugar de _showSnack con $e crudo
        handleApiError(
          context,
          e,
          prefix: 'No se pudieron cargar los pedidos',
        );
        _primeraCarga = false;
      } else {
        debugPrint('pedidos_cocina poll fallido: $e');
      }
    } finally {
      // Cambio M: _cargando siempre a false en finally para evitar spinner
      // permanente cuando el botón refresh coincide con un poll en curso.
      if (mounted) {
        setState(() {
          _pollEnCurso = false;
          _cargando = false;
        });
      } else {
        _pollEnCurso = false;
      }
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
      // Cambio C: usar handleApiError
      handleApiError(context, e, prefix: 'Error al mover pedido');
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
      // Preferimos itemId (UUID estable) frente al índice posicional para
      // evitar bugs si dos camareros editan items concurrentemente. Pedidos
      // legacy sin item_id caen al endpoint deprecado por índice.
      final itemId = (itemIdx >= 0 && itemIdx < pedido.productos.length)
          ? pedido.productos[itemIdx].itemId
          : null;
      final res = await ApiService.marcarItemHecho(
        pedidoId: pedido.id,
        itemId: itemId,
        itemIndex: itemId == null ? itemIdx : null,
        hecho: nuevo,
      );
      if (res['todosHechos'] == true) {
        await _cargarPedidos();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _itemHechoOverride[pedido.id]?.remove(itemIdx);
        if (_itemHechoOverride[pedido.id]?.isEmpty ?? false) {
          _itemHechoOverride.remove(pedido.id);
        }
      });
      // Cambio C: usar handleApiError
      handleApiError(context, e, prefix: 'Error al marcar item');
    }
  }

  // Cambio J: resumen de pedidos por estado para el AppBar en móvil
  String _resumenEstados() {
    final pendientes = _pedidos.where((p) => _estadoEfectivo(p) == 'pendiente').length;
    final preparando = _pedidos.where((p) => _estadoEfectivo(p) == 'preparando').length;
    final listos = _pedidos.where((p) => _estadoEfectivo(p) == 'listo').length;
    return '$pendientes pendientes · $preparando en cocina · $listos listos';
  }

  // Cambio E: widget del indicador de sincronización
  Widget _buildSyncIndicator() {
    if (_pausado) {
      return Text(
        'Pausado',
        style: TextStyle(
          color: AppColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    if (_ultimoExito == null) return const SizedBox.shrink();
    final segundos = DateTime.now().difference(_ultimoExito!).inSeconds;
    final info = infoUltimaActualizacion(segundos);
    return Text(
      info.texto,
      style: TextStyle(
        color: info.color,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cambio B: sustituir AppBar ad-hoc por BravoAppBar con logout.
    // BravoAppBar usa Colors.transparent como fondo y texto blanco; para
    // mantener consistencia con el fondo claro de cocina usamos un wrapper
    // con fondo oscuro del DS.
    //
    // PopScope: la pantalla del cocinero es un terminal operativo. El "atrás"
    // del sistema dejaría el Navigator vacío (login hizo pushAndRemoveUntil),
    // así que lo bloqueamos y guiamos al usuario al botón de cerrar sesión.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        showAppInfo(
          context,
          'Usa el botón "Cerrar sesión" del menú para salir',
        );
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _CocinaAppBar(
        cargando: _cargando,
        totalPedidos: _pedidos.length,
        resumenEstados: _pedidos.isEmpty ? null : _resumenEstados(),
        syncIndicator: _buildSyncIndicator(),
        pausado: _pausado,
        onTogglePausa: _togglePausa,
        onRefresh: () async {
          // Cambio M: await explícito + finally en _cargarPedidos garantiza
          // que _cargando vuelve a false siempre.
          setState(() => _cargando = true);
          await _cargarPedidos();
        },
      ),
        body: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.button),
              )
            : _sinSucursal
                ? const _SinSucursalView()
                : _buildKanban(),
      ),
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

// ── AppBar de cocina (cambio B) ──────────────────────────────────────────────
// Usa BravoAppBar internamente para heredar logout/perfil del DS.
// Se envuelve en un PreferredSize para poder añadir el subtitle de resumen
// y el indicador de sincronización en el bottom.

class _CocinaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool cargando;
  final int totalPedidos;
  final String? resumenEstados;
  final Widget syncIndicator;
  final bool pausado;
  final VoidCallback onTogglePausa;
  final VoidCallback onRefresh;

  const _CocinaAppBar({
    required this.cargando,
    required this.totalPedidos,
    required this.resumenEstados,
    required this.syncIndicator,
    required this.pausado,
    required this.onTogglePausa,
    required this.onRefresh,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 28);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bottomSheetBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila principal: título + badge + acciones (BravoAppBar)
          SizedBox(
            height: kToolbarHeight,
            child: Row(
              children: [
                // Botón atrás
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.textAppBar,
                  ),
                  tooltip: 'Atrás',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // Título
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'PEDIDOS ACTIVOS',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          color: AppColors.textAppBar,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          fontSize: 16,
                        ),
                      ),
                      if (!cargando && totalPedidos > 0) ...[
                        const SizedBox(width: 10),
                        _BadgeContador(count: totalPedidos),
                      ],
                    ],
                  ),
                ),
                // Pausar/reanudar polling
                IconButton(
                  icon: Icon(
                    pausado ? Icons.play_arrow : Icons.pause,
                    color: pausado
                        ? AppColors.warning
                        : AppColors.textAppBar,
                  ),
                  tooltip: pausado
                      ? 'Reanudar actualización automática'
                      : 'Pausar actualización automática',
                  onPressed: onTogglePausa,
                ),
                // Refresh
                IconButton(
                  icon: cargando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: AppColors.textAppBar,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.refresh,
                          color: AppColors.textAppBar,
                        ),
                  tooltip: 'Actualizar',
                  onPressed: cargando ? null : onRefresh,
                ),
                // Logout / perfil via BravoAppBar logic
                _LogoutButton(),
              ],
            ),
          ),
          // Fila inferior: resumen de estados (J) + indicador sync (E)
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: resumenEstados != null
                      ? Text(
                          resumenEstados!,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        )
                      : const SizedBox.shrink(),
                ),
                syncIndicator,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Botón de logout/perfil reutilizando la lógica de BravoAppBar
class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        icon: const Icon(Icons.logout, color: AppColors.textAppBar, size: 22),
        tooltip: 'Cerrar sesión',
        onPressed: auth.estaAutenticado
            ? () async {
                await context.read<AuthProvider>().cerrarSesion();
                if (!context.mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              }
            : null,
      ),
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
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white30),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
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
    final color = colorEstado(estado);
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
              border: Border.all(color: AppColors.bottomSheetBg, width: 1.5),
            ),
            // Cambio F: usa colorEstado (que referencia AppColors semánticos)
            child: Icon(iconoEstado(estado), color: color, size: 15),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              // Cambio I: Manrope en lugar de Playfair para texto funcional
              labelEstado(estado).toUpperCase(),
              style: TextStyle(
                fontFamily: 'Manrope',
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

  // Cambio G: icono al 40% opacidad, texto positivo en Colors.white70
  Widget _buildEmpty(Color color) {
    return Center(
      child: Semantics(
        label: 'Columna vacía: ${labelEstado(estado)}',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconoEstado(estado),
              color: color.withValues(alpha: 0.40),
              size: 38,
            ),
            const SizedBox(height: 10),
            const Text(
              'Todo listo.\nEsperando nuevos pedidos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                letterSpacing: 0.3,
                height: 1.4,
              ),
            ),
          ],
        ),
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
        // Pedidos urgentes resaltados con borde rojo y sombra fuerte para
        // que el cocinero los detecte de un vistazo entre el resto.
        border: Border.all(
          color: pedido.prioritario ? AppColors.error : AppColors.line,
          width: pedido.prioritario ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: pedido.prioritario
                ? AppColors.error.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.07),
            blurRadius: pedido.prioritario ? 8 : 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pedido.prioritario)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(11),
                      topRight: Radius.circular(11),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.priority_high,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'URGENTE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
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
    // Cambio F: usa entregaInfo, minutosDesde, colorTiempo, formatoTiempo
    // (funciones públicas del DS en cocina_helpers.dart)
    final info = entregaInfo(pedido.tipoEntrega, pedido.numeroMesa);
    final minutos = minutosDesde(pedido.fecha);
    final colorT = colorTiempo(minutos);
    return Padding(
      padding: const EdgeInsets.all(11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bottomSheetBg, width: 1.5),
            ),
            child: Icon(info.icono, color: AppColors.bottomSheetBg, size: 16),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.etiqueta,
                  // Cambio I: Manrope en texto funcional de cabecera
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  horaDesde(pedido.fecha),
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _ChipCronometro(color: colorT, texto: formatoTiempo(minutos)),
          // Cambio L: icono de drag sin Tooltip (no visible en móvil)
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.drag_indicator,
                color: AppColors.textSecondary.withValues(alpha: 0.22),
                size: 16,
              ),
            ),
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
        // Cambio D: área de toque mínima 48dp para el ítem completo
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cambio D: Checkbox sin shrinkWrap → mínimo material 48×48
              Semantics(
                label: hecho
                    ? 'Item ${p.nombre} completado'
                    : 'Marcar ${p.nombre} como hecho',
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Checkbox(
                    value: hecho,
                    onChanged: (_) => onToggleItem(pedido, idx),
                    activeColor: AppColors.button,
                    visualDensity: VisualDensity.comfortable,
                    // Cambio D: eliminado materialTapTargetSize.shrinkWrap
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 24,
                height: 24,
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
                    fontSize: 11,
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
                        // Cambio I: Manrope en texto de producto
                        fontFamily: 'Manrope',
                        color: hecho
                            ? AppColors.textSecondary.withValues(alpha: 0.6)
                            : AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        decoration: hecho
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor:
                            AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                    if (p.sin.isNotEmpty)
                      Text(
                        'Sin: ${p.sin.join(', ')}',
                        style: TextStyle(
                          color: AppColors.error.withValues(alpha: 0.85),
                          fontSize: 11,
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

  // Cambio H: notas completas sin maxLines; alergias no se cortan
  Widget _buildNotas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 0, 11, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.notes_outlined,
                size: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                pedido.notas!,
                // Cambio H: sin maxLines ni overflow; notas completas siempre
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
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
                label: labelEstado(_kEstados[idx - 1]),
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
                label: labelEstado(_kEstados[idx + 1]),
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
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Botón de acción (cambio D) ───────────────────────────────────────────────
// height: 48 (mínimo 44dp), fontSize: 13, Manrope en lugar de Playfair (I)

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
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        // Cambio D: altura mínima 48dp (táctil cómodo con guantes)
        height: 48,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary ? AppColors.button : AppColors.panel,
            foregroundColor: primary ? Colors.white : AppColors.textPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.bottomSheetBg, width: 1.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconLeft) ...[
                Icon(icon, size: 15),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  // Cambio I: Manrope en botones funcionales
                  // Cambio D: fontSize 13 (legible a distancia)
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!iconLeft) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 15),
              ],
            ],
          ),
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
                fontFamily: 'Manrope',
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
