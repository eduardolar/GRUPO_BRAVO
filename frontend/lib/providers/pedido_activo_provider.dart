// ============================================================================
// frontend/lib/providers/pedido_activo_provider.dart
// ----------------------------------------------------------------------------
// Pedido EN CURSO del cliente (ya enviado al backend, esperando).
//
// Mantiene el id, el estado, el método de entrega y el total del pedido
// activo y los persiste en SharedPreferences para que sobrevivan a un F5
// o a un reinicio.
//
// Cuando hay sesión activa y el pedido está en un estado "vivo"
// (pendiente / preparando / listo), inicia un polling cada 15s al backend
// para sincronizar el estado. Al transicionar a "listo", el watcher
// dispara una notificación local ("Tu pedido está listo").
//
// Depende de AuthProvider (vía ChangeNotifierProxyProvider en main.dart)
// para arrancar/parar el polling según haya sesión o no.
// ============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pedido_model.dart';
import '../services/notificaciones_service.dart';
import '../services/pedido_service.dart';
import 'auth_provider.dart';

// Claves de SharedPreferences
const _kPrefId = 'pedido_activo_id';
const _kPrefEstado = 'pedido_activo_estado';
const _kPrefTipoEntrega = 'pedido_activo_tipo_entrega';
const _kPrefTotal = 'pedido_activo_total';
const _kPrefReferencia = 'pedido_activo_referencia';

const _kEstadosActivos = {'pendiente', 'preparando', 'listo'};
const _kPollInterval = Duration(seconds: 15);

/// Mantiene el seguimiento persistente del último pedido activo del cliente.
///
/// - Lee de SharedPreferences al arrancar para mostrar la pill al instante.
/// - Hace polling cada 15 s para refrescar el estado desde la API.
/// - Escucha [AuthProvider]: cuando el usuario cierra sesión llama a [detener].
/// - Dispara notificación local cuando el pedido pasa a estado `listo`.
class PedidoActivoProvider extends ChangeNotifier {
  PedidoActivoProvider(AuthProvider auth) {
    _authProvider = auth;
    auth.addListener(_onAuthCambio);
    if (auth.estaAutenticado && auth.usuarioActual != null) {
      iniciar(auth.usuarioActual!.id);
    }
  }

  late final AuthProvider _authProvider;

  Pedido? _pedidoActivo;
  final bool _cargando = false;
  bool _hayError = false;
  bool _pollPausado = false;
  Timer? _timer;
  String? _userId;
  String? _ultimoEstadoNotificado;

  Pedido? get pedidoActivo => _pedidoActivo;
  bool get cargando => _cargando;
  bool get hayError => _hayError;

  /// La pill debe mostrarse cuando hay un pedido activo.
  bool get pillVisible => _pedidoActivo != null;

  // ── Ciclo de vida ────────────────────────────────────────────────────────

  /// Arranca el polling. Lee SharedPreferences primero para evitar parpadeo.
  Future<void> iniciar(String userId) async {
    if (userId.isEmpty) return;
    _userId = userId;
    _pollPausado = false;

    // Mostrar inmediatamente desde caché para evitar parpadeo
    await _leerCache();

    // Primera carga real y arrancar timer periódico
    await _cargar();
    _timer?.cancel();
    _timer = Timer.periodic(_kPollInterval, (_) {
      if (!_pollPausado) _cargar();
    });
  }

  /// Pausa el polling (usado por PedidoConfirmadoScreen que tiene su propio poll).
  void pausarPolling() => _pollPausado = true;

  /// Reanuda el polling y hace un refresco inmediato.
  void reanudarPolling() {
    _pollPausado = false;
    _cargar();
  }

  /// Cancela el timer y borra estado en memoria y SharedPreferences.
  Future<void> detener() async {
    _timer?.cancel();
    _timer = null;
    _userId = null;
    _pollPausado = false;
    _pedidoActivo = null;
    _ultimoEstadoNotificado = null;
    await _borrarCache();
    notifyListeners();
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthCambio);
    _timer?.cancel();
    super.dispose();
  }

  // ── Lógica interna ───────────────────────────────────────────────────────

  void _onAuthCambio() {
    if (!_authProvider.estaAutenticado) {
      detener();
    } else {
      final uid = _authProvider.usuarioActual?.id;
      if (uid != null && uid != _userId) {
        iniciar(uid);
      }
    }
  }

  Future<void> _cargar() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) return;

    try {
      _hayError = false;
      final pedidos = await PedidoService.obtenerHistorialPedidos(
        userId: userId,
      );

      // Filtra activos y ordena por fecha descendente
      final activos = pedidos
          .where((p) => _kEstadosActivos.contains(p.estado))
          .toList()
        ..sort((a, b) => b.fecha.compareTo(a.fecha));

      final nuevo = activos.isEmpty ? null : activos.first;
      final previo = _pedidoActivo;

      // Solo notifica al árbol si hubo un cambio real
      final cambioReal =
          previo?.id != nuevo?.id || previo?.estado != nuevo?.estado;

      if (nuevo == null) {
        _pedidoActivo = null;
        await _borrarCache();
      } else {
        // Disparar notificación local si el estado acaba de pasar a `listo`
        if (nuevo.estado == 'listo' &&
            previo?.estado != 'listo' &&
            _ultimoEstadoNotificado != nuevo.id) {
          _ultimoEstadoNotificado = nuevo.id;
          _dispararNotificacionListo(nuevo.id);
        }
        _pedidoActivo = nuevo;
        await _persistirCache(nuevo);
      }

      if (cambioReal) notifyListeners();
    } catch (e) {
      debugPrint('PedidoActivoProvider: error en polling: $e');
      _hayError = true;
      notifyListeners();
    }
  }

  Future<void> _leerCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_kPrefId);
      if (id == null || id.isEmpty) return;
      final estado = prefs.getString(_kPrefEstado) ?? '';
      if (!_kEstadosActivos.contains(estado)) {
        // Estado ya no activo → caché obsoleta
        await _borrarCache();
        return;
      }
      // Construye un Pedido mínimo desde caché para renderizar la pill al instante
      _pedidoActivo = Pedido(
        id: id,
        fecha: '',
        total: prefs.getDouble(_kPrefTotal) ?? 0,
        estado: estado,
        items: 0,
        tipoEntrega: prefs.getString(_kPrefTipoEntrega) ?? '',
        metodoPago: '',
        productos: [],
      );
      notifyListeners();
    } catch (e) {
      debugPrint('PedidoActivoProvider: error leyendo caché: $e');
    }
  }

  Future<void> _persistirCache(Pedido pedido) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefId, pedido.id);
      await prefs.setString(_kPrefEstado, pedido.estado);
      await prefs.setString(_kPrefTipoEntrega, pedido.tipoEntrega);
      await prefs.setDouble(_kPrefTotal, pedido.total);
      final ref = pedido.id.length > 6
          ? pedido.id.substring(pedido.id.length - 6).toUpperCase()
          : pedido.id.toUpperCase();
      await prefs.setString(_kPrefReferencia, ref);
    } catch (e) {
      debugPrint('PedidoActivoProvider: error persistiendo caché: $e');
    }
  }

  Future<void> _borrarCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrefId);
      await prefs.remove(_kPrefEstado);
      await prefs.remove(_kPrefTipoEntrega);
      await prefs.remove(_kPrefTotal);
      await prefs.remove(_kPrefReferencia);
    } catch (e) {
      debugPrint('PedidoActivoProvider: error borrando caché: $e');
    }
  }

  void _dispararNotificacionListo(String pedidoId) {
    if (kIsWeb) return;
    NotificacionesService.instance.mostrarPedidoListo(
      notifId: pedidoId.hashCode & 0x7fffffff,
      pedidoId: pedidoId,
    );
  }
}
