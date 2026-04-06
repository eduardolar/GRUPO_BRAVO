import 'package:flutter/material.dart';
import '../models/usuario_model.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  Usuario? _usuarioActual;

  Usuario? get usuarioActual => _usuarioActual;
  bool get estaAutenticado => _usuarioActual != null;

  // Método para iniciar sesión
  Future<bool> iniciarSesion(String email, String contrasena) async {
    try {
      final response = await ApiService.iniciarSesion(
        correo: email,
        contrasena: contrasena,
      );

      _usuarioActual = Usuario.fromJson(response);

      notifyListeners();
      return true;
    } catch (e) {
      throw Exception('Credenciales incorrectas');
    }
  }

  // Método para registrarse
  Future<bool> registrarse({
    required String nombre,
    required String email,
    required String contrasena,
    required String telefono,
    required String direccion,
  }) async {
    try {
      final response = await ApiService.registrarUsuario(
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

  // Método para actualizar perfil
  Future<void> actualizarPerfil({
    required String nombre,
    required String email,
    required String telefono,
    required String direccion,
  }) async {
    if (_usuarioActual == null) return;

    await ApiService.actualizarPerfil(
      userId: _usuarioActual!.id,
      nombre: nombre,
      email: email,
      telefono: telefono,
      direccion: direccion,
    );

    _usuarioActual = _usuarioActual!.copyWith(
      nombre: nombre,
      email: email,
      telefono: telefono,
      direccion: direccion,
    );
    notifyListeners();
  }

  // Método para eliminar cuenta
  Future<void> eliminarCuenta() async {
    if (_usuarioActual == null) return;
    await ApiService.eliminarCuenta(userId: _usuarioActual!.id);
    _usuarioActual = null;
    notifyListeners();
  }

  // Método para cerrar sesión
  void cerrarSesion() {
    _usuarioActual = null;
    notifyListeners();
  }
}
