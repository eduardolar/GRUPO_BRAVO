import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario_model.dart';

class AuthProvider with ChangeNotifier {
  Usuario? _usuarioActual;
  
  // IP de tu PC (poner aqui tu ip real , no localhost)
  final String _baseUrl = "http://192.168.1.134:8000";

  Usuario? get usuarioActual => _usuarioActual;
  bool get estaAutenticado => _usuarioActual != null;

  // LOGIN REAL
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
        // Aquí podrías crear el objeto usuario con lo que devuelve tu API
        _usuarioActual = Usuario(
          id: 'temp_id', 
          nombre: data['nombre'],
          email: email,
          contrasena: contrasena,
          telefono: '',
          direccion: '',
        );
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // REGISTRO REAL (Directo a comandas_db)
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
          'correo': email,
          'password_hash': contrasena,
          'telefono': telefono,
          'direccion': direccion,
          'rol': 'cliente'
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        _usuarioActual = Usuario(
          id: responseData['id'],
          nombre: nombre,
          email: email,
          contrasena: contrasena,
          telefono: telefono,
          direccion: direccion,
        );
        notifyListeners();
        return true;
      } else {
        final errorMsg = jsonDecode(response.body)['detail'] ?? 'Error desconocido';
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('Servidor no alcanzado. Revisa tu IP: $e');
    }
  }

  void cerrarSesion() {
    _usuarioActual = null;
    notifyListeners();
  }
}