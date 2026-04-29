import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  Usuario? _usuarioActual;
  String? _pendingUserId2fa;
  static const _kSesionKey = 'usuario_sesion';

  Usuario? get usuarioActual => _usuarioActual;
  bool get estaAutenticado => _usuarioActual != null;

  /// ID temporal durante el flujo de login con 2FA activo.
  String? get pendingUserId2fa => _pendingUserId2fa;

  Future<void> cargarSesion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kSesionKey);
      if (json != null) {
        _usuarioActual = Usuario.fromJson(jsonDecode(json) as Map<String, dynamic>);
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

  /// Devuelve `true` si el login fue completo.
  /// Devuelve `false` si se requiere 2FA (consultar [pendingUserId2fa]).
  Future<bool> iniciarSesion(String email, String contrasena) async {
    try {
      final response = await AuthService.iniciarSesion(correo: email, contrasena: contrasena);
      if (response['requires_2fa'] == true) {
        _pendingUserId2fa = response['user_id'] as String?;
        notifyListeners();
        return false;
      }
      _pendingUserId2fa = null;
      _usuarioActual = Usuario.fromJson(response);
      notifyListeners();
      await _guardarSesion();
      return true;
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
  }) async {
    try {
      final response = await AuthService.registrarUsuario(
        nombre: nombre,
        correo: email,
        contrasena: contrasena,
        telefono: telefono,
        direccion: direccion,
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
      userId: _usuarioActual!.id,
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
      userId: _usuarioActual!.id,
      passwordActual: passwordActual,
      nuevaPassword: nuevaPassword,
    );
  }

  Future<void> eliminarCuenta() async {
    if (_usuarioActual == null) throw Exception('No hay usuario autenticado');
    final success = await AuthService.eliminarCuenta(userId: _usuarioActual!.id);
    if (!success) throw Exception('Error al eliminar la cuenta');
    _usuarioActual = null;
    notifyListeners();
    await _limpiarSesion();
  }

  Future<void> cerrarSesion() async {
    _usuarioActual = null;
    _pendingUserId2fa = null;
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
    final data = await AuthService.activar2fa(userId: _usuarioActual!.id, codigo: codigo);
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
}
