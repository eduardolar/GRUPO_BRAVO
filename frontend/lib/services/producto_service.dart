import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/producto_model.dart';
import '../data/mock_data.dart';
import 'api_config.dart';

class ProductoService {
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

  /// Obtener productos (opcionalmente filtrados por categoría)
  static Future<List<Producto>> obtenerProductos({String? categoria}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      final productos = MockData.productos;
      if (categoria != null) {
        return productos.where((p) => p.categoria == categoria).toList();
      }
      return List.from(productos);
    }

    final uri = categoria != null
        ? Uri.parse('$baseUrl/productos?categoria=$categoria')
        : Uri.parse('$baseUrl/productos');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Producto.fromMap(json)).toList();
    } else {
      throw Exception('Error al obtener productos');
    }
  }
}
