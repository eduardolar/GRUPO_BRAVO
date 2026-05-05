import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../models/pedido_model.dart';
import 'notificaciones_service.dart';
import 'pedido_service.dart';

/// Vigila los pedidos del usuario logueado y dispara una notificación local
/// cuando alguno pasa a estado `listo`.
///
/// Polling-based (no FCM): consulta el backend cada [pollInterval]. Para
/// distinguir transiciones reales del estado inicial, los IDs ya conocidos
/// como `listo` en la primera carga se ignoran.
class PedidoListoWatcher {
  PedidoListoWatcher._();
  static final PedidoListoWatcher instance = PedidoListoWatcher._();

  static const Duration pollInterval = Duration(seconds: 30);

  Timer? _timer;
  String? _userIdActivo;
  final Set<String> _yaNotificados = {};
  final Set<String> _idsListosIniciales = {};
  bool _primeraLectura = true;

  bool get activo => _timer != null;

  /// Arranca el watcher para un usuario. Si ya está corriendo para otro
  /// usuario, lo reinicia con el nuevo.
  Future<void> iniciar(String userId) async {
    if (userId.isEmpty) return;
    if (_userIdActivo == userId && _timer != null) return;

    detener();
    _userIdActivo = userId;
    _yaNotificados.clear();
    _idsListosIniciales.clear();
    _primeraLectura = true;

    await NotificacionesService.instance.inicializar();
    await _checkOnce();
    _timer = Timer.periodic(pollInterval, (_) => _checkOnce());
  }

  void detener() {
    _timer?.cancel();
    _timer = null;
    _userIdActivo = null;
  }

  Future<void> _checkOnce() async {
    final userId = _userIdActivo;
    if (userId == null) return;
    try {
      final pedidos = await PedidoService.obtenerHistorialPedidos(
        userId: userId,
      );
      _procesarPedidos(pedidos);
    } catch (e) {
      debugPrint('PedidoListoWatcher: error consultando pedidos: $e');
    }
  }

  void _procesarPedidos(List<Pedido> pedidos) {
    for (final p in pedidos) {
      if (p.estado != 'listo') continue;
      // En la primera lectura, marcar como "ya estaba listo" — no notificar
      // pedidos que ya estaban en ese estado antes de arrancar el watcher.
      if (_primeraLectura) {
        _idsListosIniciales.add(p.id);
        continue;
      }
      if (_idsListosIniciales.contains(p.id)) continue;
      if (_yaNotificados.contains(p.id)) continue;
      _yaNotificados.add(p.id);
      NotificacionesService.instance.mostrarPedidoListo(
        notifId: p.id.hashCode & 0x7fffffff,
        pedidoId: p.id,
      );
    }
    _primeraLectura = false;
  }
}
