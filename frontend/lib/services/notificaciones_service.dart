import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Servicio singleton para notificaciones locales (no FCM).
///
/// Inicializa una sola vez al arrancar la app y luego dispara notificaciones
/// del sistema cuando el watcher detecta un cambio de estado.
class NotificacionesService {
  NotificacionesService._();
  static final NotificacionesService instance = NotificacionesService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _inicializado = false;

  static const _kCanalPedidoListoId = 'pedido_listo';
  static const _kCanalPedidoListoNombre = 'Pedido listo';
  static const _kCanalPedidoListoDesc =
      'Avisa cuando tu pedido está listo para recoger o servir.';

  Future<void> inicializar() async {
    if (_inicializado || kIsWeb) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(initSettings);

    // Android 13+ requiere pedir permiso explícito.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    }

    _inicializado = true;
  }

  Future<void> mostrarPedidoListo({
    required int notifId,
    required String pedidoId,
  }) async {
    if (kIsWeb || !_inicializado) return;

    const androidDetails = AndroidNotificationDetails(
      _kCanalPedidoListoId,
      _kCanalPedidoListoNombre,
      channelDescription: _kCanalPedidoListoDesc,
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final referenciaCorta =
        pedidoId.length > 6 ? pedidoId.substring(pedidoId.length - 6) : pedidoId;

    await _plugin.show(
      notifId,
      'Tu pedido está listo',
      'Pedido #${referenciaCorta.toUpperCase()} · pasa a recogerlo',
      details,
    );
  }
}
