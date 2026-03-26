import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario_model.dart';

class AuthProvider with ChangeNotifier {
  Usuario? _usuarioActual;
  Usuario? get usuarioActual => _usuarioActual;
  bool get estaAutenticado => _usuarioActual != null;

  // IP para Chrome. 
  final String _baseUrl = 'http://127.0.0.1:8000'; 

  // Método de registro
  Future<bool> registrarse({
    required String nombre,
    required String email,
    required String contrasena,
    required String telefono,
    required String direccion,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/registro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre,
          'password_hash': contrasena, // Coincide con tu Pydantic en Python
          'correo': email,
          'telefono': telefono,
          'direccion': direccion,
          'rol': 'cliente',
        }),
      );

      if (response.statusCode == 200) {
        // Registro exitoso en MongoDB
        _usuarioActual = Usuario(
          id: 'nuevo',
          nombre: nombre,
          email: email,
          contrasena: contrasena,
          telefono: telefono,
          direccion: direccion,
        );
        notifyListeners();
        return true;
      } else {
        // El servidor respondió con un error (ej: correo ya existe)
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Error en el servidor');
      }
    } catch (e) {
      // Error de red o servidor apagado
      throw Exception('No se pudo conectar con el servidor: $e');
    }
  }

  // Método de inicio de sesión
  Future<bool> iniciarSesion(String email, String contrasena) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correo': email,
          'password_hash': contrasena,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _usuarioActual = Usuario(
          id: 'registrado',
          nombre: data['nombre'],
          email: email,
          contrasena: contrasena,
          telefono: '',
          direccion: '',
        );
        notifyListeners();
        return true;
      } else {
        throw Exception('Usuario o contraseña incorrectos');
      }
    } catch (e) {
      throw Exception('Error al conectar con el servidor: $e');
    }
  }

  void cerrarSesion() {
    _usuarioActual = null;
    notifyListeners();
  }
}