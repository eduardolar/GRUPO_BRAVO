import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ingrediente_model.dart';
import '../data/mock_data.dart';
import 'api_config.dart';

class IngredienteService {
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
      final ingredientes = MockData.productos
          .where((p) => categoria == null || p.categoria == categoria)
          .map((p) => Ingrediente(id: p.id, nombre: p.nombre))
          .toList();
      return ingredientes;
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
