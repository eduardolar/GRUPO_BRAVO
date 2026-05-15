// ============================================================================
// frontend/lib/providers/auth_provider.dart
// ----------------------------------------------------------------------------
// Estado de la sesión expuesto al árbol de widgets (vía Provider).
//
// Mantiene:
//   - _usuarioActual: objeto Usuario completo (id, nombre, rol, etc.).
//   - _pendingUserId2fa: id "en tránsito" durante el flujo de 2FA.
//
// Persiste el objeto Usuario en SharedPreferences (clave `usuario_sesion`)
// para sobrevivir a F5/reinicio. El token JWT se persiste en paralelo via
// `AuthSession` (clave `auth_token`).
//
// Por qué dos almacenamientos:
//   - AuthSession: token y datos mínimos para añadir Authorization en cada
//     request HTTP (lo lee directamente http_client).
//   - AuthProvider: objeto completo del usuario, expuesto a la UI con
//     ChangeNotifier para que widgets como `_HomePorRol` se reconstruyan
//     automáticamente al cambiar (login/logout).
// ============================================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';

class AuthProvider with ChangeNotifier {
  Usuario? _usuarioActual;
  String? _pendingUserId2fa;
  static const _kSesionKey = 'usuario_sesion';

  Usuario? get usuarioActual => _usuarioActual;
  bool get estaAutenticado => _usuarioActual != null;

  /// ID temporal durante el flujo de login con 2FA activo.
  String? get pendingUserId2fa => _pendingUserId2fa;

  Future<void> cargarSesion() async {
    // Primero restaurar el token JWT; si no hay token, la UI no intentará
    // llamadas autenticadas aunque sí haya objeto Usuario guardado.
    await AuthSession.cargar();
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kSesionKey);
      if (json != null) {
        _usuarioActual = Usuario.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('cargarSesion: no se pudo restaurar la sesión ($e)');
    }
  }

  Future<void> _guardarSesion() async {
    if (_usuarioActual == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSesionKey, jsonEncode(_usuarioActual!.toJson()));
  }

  Future<void> _limpiarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSesionKey);
  }

  Future<bool> verificarCodigo(String email, String codigo) async {
    try {
      await AuthService.verificarCodigo(correo: email, codigo: codigo);
      if (_usuarioActual != null && _usuarioActual!.email == email) {
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint("Error en verificarCodigo Provider: $e");
      rethrow;
    }
  }

  /// Devuelve un Map con la respuesta si requiere 2FA, o null si el login fue exitoso.
  /// Si devuelve un Map, contiene 'requires_2fa': true y 'correo' del usuario.
  Future<Map<String, dynamic>?> iniciarSesion(
    String email,
    String contrasena,
  ) async {
    try {
      final response = await AuthService.iniciarSesion(
        correo: email,
        contrasena: contrasena,
      );
      if (response['requires_2fa'] == true) {
        _pendingUserId2fa = response['user_id'] as String?;
        notifyListeners();
        return response; // Devolver la respuesta completa para acceder a 'correo'
      }
      _pendingUserId2fa = null;
      _usuarioActual = Usuario.fromJson(response);
      notifyListeners();
      await _guardarSesion();
      return null; // Login exitoso, no requiere 2FA
    } catch (e) {
      rethrow;
    }
  }

  /// Completa el login verificando el código TOTP.
  Future<void> completarLogin2fa(String codigo) async {
    if (_pendingUserId2fa == null) throw Exception('No hay login pendiente');
    final response = await AuthService.verificar2fa(
      userId: _pendingUserId2fa!,
      codigo: codigo,
    );
    _pendingUserId2fa = null;
    _usuarioActual = Usuario.fromJson(response);
    notifyListeners();
    await _guardarSesion();
  }

  Future<bool> registrarse({
    required String nombre,
    required String email,
    required String contrasena,
    required String telefono,
    required String direccion,
    String? restauranteId,
    required bool consentimientoRgpd,
  }) async {
    try {
      final response = await AuthService.registrarUsuario(
        nombre: nombre,
        correo: email,
        contrasena: contrasena,
        telefono: telefono,
        direccion: direccion,
        restauranteId: restauranteId,
        consentimientoRgpd: consentimientoRgpd,
      );
      _usuarioActual = Usuario(
        id: response['id'] ?? '',
        nombre: nombre,
        email: email,
        contrasena: contrasena,
        telefono: telefono,
        direccion: direccion,
      );
      notifyListeners();
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> recuperarPassword(String email) async {
    await AuthService.recuperarPassword(correo: email);
  }

  Future<void> resetPassword({
    required String email,
    required String codigo,
    required String nuevaPassword,
  }) async {
    await AuthService.resetPassword(
      correo: email,
      codigo: codigo,
      nuevaPassword: nuevaPassword,
    );
  }

  Future<void> reenviarCodigo(String email) async {
    await AuthService.reenviarCodigo(correo: email);
  }

  Future<void> actualizarPerfil({
    required String nombre,
    required String email,
    required String telefono,
    required String direccion,
  }) async {
    if (_usuarioActual == null) throw Exception('No hay usuario autenticado');
    final success = await AuthService.actualizarPerfil(
      nombre: nombre,
      email: email,
      telefono: telefono,
      direccion: direccion,
    );
    if (!success) throw Exception('Error al actualizar el perfil');
    _usuarioActual = _usuarioActual!.copyWith(
      nombre: nombre,
      email: email,
      telefono: telefono,
      direccion: direccion,
    );
    notifyListeners();
    await _guardarSesion();
  }

  Future<void> cambiarContrasena({
    required String passwordActual,
    required String nuevaPassword,
  }) async {
    if (_usuarioActual == null) throw Exception('No hay usuario autenticado');
    await AuthService.cambiarContrasena(
      passwordActual: passwordActual,
      nuevaPassword: nuevaPassword,
    );
  }

  Future<void> eliminarCuenta() async {
    if (_usuarioActual == null) throw Exception('No hay usuario autenticado');
    final success = await AuthService.eliminarCuenta();
    if (!success) throw Exception('Error al eliminar la cuenta');
    _usuarioActual = null;
    await AuthSession.limpiar();
    notifyListeners();
    await _limpiarSesion();
  }

  Future<void> cerrarSesion() async {
    _usuarioActual = null;
    _pendingUserId2fa = null;
    await AuthSession.limpiar();
    notifyListeners();
    await _limpiarSesion();
  }

  void actualizarDireccionLocal({
    required String nuevaDir,
    required double nuevaLat,
    required double nuevaLon,
  }) {
    if (_usuarioActual != null) {
      _usuarioActual = _usuarioActual!.copyWith(
        direccion: nuevaDir,
        latitud: nuevaLat,
        longitud: nuevaLon,
      );
      notifyListeners();
    }
  }

  // --- 2FA ---

  Future<Map<String, dynamic>> setup2fa() async {
    if (_usuarioActual == null) throw Exception('No hay usuario autenticado');
    return AuthService.setup2fa(userId: _usuarioActual!.id);
  }

  Future<List<String>> activar2fa(String codigo) async {
    if (_usuarioActual == null) throw Exception('No hay usuario autenticado');
    final data = await AuthService.activar2fa(
      userId: _usuarioActual!.id,
      codigo: codigo,
    );
    _usuarioActual = _usuarioActual!.copyWith(totpEnabled: true);
    notifyListeners();
    await _guardarSesion();
    return List<String>.from(data['codigosRecuperacion'] as List);
  }

  Future<void> completarLogin2faRecovery(String codigo) async {
    if (_pendingUserId2fa == null) throw Exception('No hay login pendiente');
    final response = await AuthService.verificar2faRecovery(
      userId: _pendingUserId2fa!,
      codigo: codigo,
    );
    _pendingUserId2fa = null;
    _usuarioActual = Usuario.fromJson(response);
    notifyListeners();
    await _guardarSesion();
  }

  Future<List<String>> regenerarCodigosRecuperacion(String codigo) async {
    if (_usuarioActual == null) throw Exception('No hay usuario autenticado');
    return AuthService.regenerarCodigosRecuperacion(
      userId: _usuarioActual!.id,
      codigo: codigo,
    );
  }

  Future<void> desactivar2fa(String codigo) async {
    if (_usuarioActual == null) throw Exception('No hay usuario autenticado');
    await AuthService.desactivar2fa(userId: _usuarioActual!.id, codigo: codigo);
    _usuarioActual = _usuarioActual!.copyWith(totpEnabled: false);
    notifyListeners();
    await _guardarSesion();
  }

  Future<void> solicitarCodigoEmail2FA() async {
    if (_usuarioActual == null) throw Exception('No hay usuario autenticado');
    await AuthService.solicitarCodigoEmail2FA(userId: _usuarioActual!.id);
  }

  Future<void> activarEmail2FA(String codigo) async {
    if (_usuarioActual == null) throw Exception('No hay usuario autenticado');
    await AuthService.activarEmail2FA(
      userId: _usuarioActual!.id,
      codigo: codigo,
    );
    _usuarioActual = _usuarioActual!.copyWith(emailDosFactoresEnabled: true);
    notifyListeners();
    await _guardarSesion();
  }

  Future<void> desactivarEmail2FA(String codigo) async {
    if (_usuarioActual == null) throw Exception('No hay usuario autenticado');
    await AuthService.desactivarEmail2FA(
      userId: _usuarioActual!.id,
      codigo: codigo,
    );
    _usuarioActual = _usuarioActual!.copyWith(emailDosFactoresEnabled: false);
    notifyListeners();
    await _guardarSesion();
  }

  Future<bool> verificarLogin2FA(String correo, String codigo) async {
    try {
      final userData = await AuthService.verificarLogin2FA(correo, codigo);
      _usuarioActual = Usuario.fromJson(userData);
      notifyListeners();
      await _guardarSesion();
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reenviarLogin2FA(String correo) async {
    try {
      await AuthService.reenviarLogin2FA(correo: correo);
    } catch (e) {
      rethrow;
    }
  }
  // --- ACTUALIZAR PUNTOS TRAS COMPRA ---
  void descontarPuntosLocales(int puntosUsados) {
    if (_usuarioActual != null && puntosUsados > 0) {
      final puntosActuales = _usuarioActual!.puntos;
      final nuevosPuntos = puntosActuales - puntosUsados;
      
      _usuarioActual = _usuarioActual!.copyWith(
        puntos: nuevosPuntos < 0 ? 0 : nuevosPuntos,
      );
      
      notifyListeners();
      _guardarSesion(); // Guardamos el nuevo saldo en la memoria del móvil
    }
  }
}
