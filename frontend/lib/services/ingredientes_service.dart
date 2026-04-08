import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ingrediente_model.dart';
import '../data/mock_data.dart';
import 'api_config.dart';

class IngredienteService {
  // Datos mock para ingredientes
  static final List<Ingrediente> _mockIngredientes = [
    Ingrediente(id: '1', nombre: 'Tomate', cantidadActual: 50, unidad: 'kg', stockMinimo: 10),
    Ingrediente(id: '2', nombre: 'Queso', cantidadActual: 20, unidad: 'kg', stockMinimo: 5),
    Ingrediente(id: '3', nombre: 'Lechuga', cantidadActual: 15, unidad: 'kg', stockMinimo: 8),
    Ingrediente(id: '4', nombre: 'Carne', cantidadActual: 30, unidad: 'kg', stockMinimo: 12),
    Ingrediente(id: '5', nombre: 'Pan', cantidadActual: 100, unidad: 'unidades', stockMinimo: 20),
  ];

  /// Obtener lista de categorías
  static Future<List<String>> obtenerCategorias() async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 200));
      return List.from(MockData.categorias);
    }

    final response = await http.get(Uri.parse('$baseUrl/categorias'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<String>();
    } else {
      throw Exception('Error al obtener categorías');
    }
  }

  /// Obtener ingredientes (opcionalmente filtrados por categoría)
  static Future<List<Ingrediente>> obtenerIngredientes({String? categoria}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return List.from(_mockIngredientes);
    }

    final uri = categoria != null
        ? Uri.parse('$baseUrl/ingredientes?categoria=$categoria')
        : Uri.parse('$baseUrl/ingredientes');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Ingrediente.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener ingredientes');
    }
  }
}
