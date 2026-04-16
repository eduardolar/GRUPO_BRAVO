import 'package:flutter/material.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart'; // Asegúrate de que el path sea correcto

class AuthProvider with ChangeNotifier {
  Usuario? _usuarioActual;

  Usuario? get usuarioActual => _usuarioActual;
  bool get estaAutenticado => _usuarioActual != null;

  // Lógica para verificar el código
  Future<bool> verificarCodigo(String email, String codigo) async {
    try {
      // Llamamos al método estático de AuthService
      await AuthService.verificarCodigo(
        correo: email,
        codigo: codigo,
      );

      // AuthService ya lanza excepción en caso de error; si llegamos aquí el código es válido
      if (_usuarioActual != null && _usuarioActual!.email == email) {
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint("Error en verificarCodigo Provider: $e");
      rethrow; // Reenviamos el error para que la UI lo muestre
    }
  }

  Future<bool> iniciarSesion(String email, String contrasena) async {
    try {
      final response = await AuthService.iniciarSesion(correo: email, contrasena: contrasena);
      _usuarioActual = Usuario.fromJson(response);
      notifyListeners();
      return true;
    } catch (e) {
      rethrow;
    }
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
      // Tras el registro, el usuario aún no está verificado en la DB
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
    final success = await AuthService.eliminarCuenta(
      userId: _usuarioActual!.id,
    );
    if (!success) throw Exception('Error al eliminar la cuenta');
    _usuarioActual = null;
    notifyListeners();
  }

  void cerrarSesion() {
    _usuarioActual = null;
    notifyListeners();
  }
}