import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/usuario_model.dart';

class AuthProvider with ChangeNotifier {
  Usuario? _usuarioActual;

  Usuario? get usuarioActual => _usuarioActual;
  bool get estaAutenticado => _usuarioActual != null;

  // Método para iniciar sesión
  Future<bool> iniciarSesion(String email, String contrasena) async {
    // Simular delay de red
    await Future.delayed(const Duration(seconds: 1));

    // Buscar usuario en mock data
    try {
      final usuario = MockData.usuarios.firstWhere(
        (u) => u.email == email && u.contrasena == contrasena,
      );

      _usuarioActual = usuario;
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
    // Simular delay de red
    await Future.delayed(const Duration(seconds: 1));

    // Verificar si el email ya existe
    final emailExiste = MockData.usuarios.any((u) => u.email == email);
    if (emailExiste) {
      throw Exception('El email ya está registrado');
    }

    // Crear nuevo usuario
    final nuevoUsuario = Usuario(
      id: 'u_${MockData.usuarios.length + 1}',
      nombre: nombre,
      email: email,
      contrasena: contrasena,
      telefono: telefono,
      direccion: direccion,
    );

    // Agregar a mock data (en una app real, esto iría a una API)
    MockData.usuarios.add(nuevoUsuario);

    _usuarioActual = nuevoUsuario;
    notifyListeners();
    return true;
  }

  // Método para cerrar sesión
  void cerrarSesion() {
    _usuarioActual = null;
    notifyListeners();
  }
}