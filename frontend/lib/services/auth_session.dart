/// Mantiene el token JWT emitido por el backend tras un login satisfactorio
/// y lo persiste en SharedPreferences para sobrevivir recargas de página (web)
/// o reinicios de la app.
///
/// Nota sobre seguridad: se usa SharedPreferences (localStorage en web) en
/// lugar de flutter_secure_storage porque en web ambos caen sobre localStorage
/// igualmente, y flutter_secure_storage añade dependencias nativas innecesarias
/// para el riesgo que resuelve. Decisión revisable si la app añade targets
/// móviles con requisitos de seguridad estrictos.
///
/// Claves usadas: `auth_token`, `auth_user_id`, `auth_correo`, `auth_rol`.
/// NO colisionan con `usuario_sesion` que usa AuthProvider para el objeto
/// Usuario completo en JSON.
///
/// Hook de cierre de sesión automático: registrar [onUnauthorized] para que
/// la app reaccione cuando el backend devuelva un 401 con sesión activa.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  static String? _token;
  static String? _userId;
  static String? _correo;
  static String? _rol;

  // Claves SharedPreferences.
  static const _kToken = 'auth_token';
  static const _kUserId = 'auth_user_id';
  static const _kCorreo = 'auth_correo';
  static const _kRol = 'auth_rol';

  /// Callback invocado automáticamente cuando el backend devuelve un 401
  /// con sesión activa. La app principal lo registra en main.dart.
  /// Si es null, no se hace nada especial con los 401.
  static FutureOr<void> Function()? onUnauthorized;

  // ---------------------------------------------------------------------------
  // Persistencia
  // ---------------------------------------------------------------------------

  /// Carga la sesión previamente guardada en SharedPreferences.
  /// Se llama una sola vez al arrancar, antes de notificar listeners.
  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kToken);
      if (token == null || token.isEmpty) return; // sin sesión guardada
      _token = token;
      _userId = prefs.getString(_kUserId);
      _correo = prefs.getString(_kCorreo);
      _rol = prefs.getString(_kRol);
    } catch (e) {
      debugPrint('AuthSession.cargar: no se pudo restaurar la sesión ($e)');
    }
  }

  /// Guarda los datos de la sesión recibidos del backend y los persiste.
  static Future<void> guardar({
    required String? token,
    String? userId,
    String? correo,
    String? rol,
  }) async {
    _token = (token != null && token.isNotEmpty) ? token : null;
    _userId = userId;
    _correo = correo;
    _rol = rol;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (_token != null) {
        await prefs.setString(_kToken, _token!);
      } else {
        await prefs.remove(_kToken);
      }
      if (userId != null) {
        await prefs.setString(_kUserId, userId);
      } else {
        await prefs.remove(_kUserId);
      }
      if (correo != null) {
        await prefs.setString(_kCorreo, correo);
      } else {
        await prefs.remove(_kCorreo);
      }
      if (rol != null) {
        await prefs.setString(_kRol, rol);
      } else {
        await prefs.remove(_kRol);
      }
    } catch (e) {
      debugPrint('AuthSession.guardar: no se pudo persistir la sesión ($e)');
    }
  }

  /// Borra todo rastro del token en memoria y en SharedPreferences (logout).
  static Future<void> limpiar() async {
    _token = null;
    _userId = null;
    _correo = null;
    _rol = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kToken);
      await prefs.remove(_kUserId);
      await prefs.remove(_kCorreo);
      await prefs.remove(_kRol);
    } catch (e) {
      debugPrint('AuthSession.limpiar: no se pudo limpiar la sesión ($e)');
    }
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  static String? get token => _token;
  static String? get userId => _userId;
  static String? get correo => _correo;
  static String? get rol => _rol;
  static bool get autenticado => _token != null;

  /// Construye los headers HTTP estándar añadiendo `Authorization: Bearer`
  /// cuando hay sesión activa. Si [extra] colisiona, prevalece [extra].
  static Map<String, String> headers({
    Map<String, String>? extra,
    bool json = true,
  }) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    if (_token != null) h['Authorization'] = 'Bearer $_token';
    if (extra != null) h.addAll(extra);
    return h;
  }
}
